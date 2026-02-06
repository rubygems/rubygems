# frozen_string_literal: true

require_relative "../worker"
require_relative "gem_installer"
require_relative "progress_reporter"

module Bundler
  class ParallelInstaller
    class SpecInstallation
      attr_accessor :spec, :name, :full_name, :post_install_message, :state, :error
      attr_accessor :download_state, :has_native_ext

      def initialize(spec)
        @spec = spec
        @name = spec.name
        @full_name = spec.full_name
        @state = :none
        @download_state = :none # :none, :enqueued, :downloaded, :failed
        @post_install_message = ""
        @error = nil
        @has_native_ext = detect_native_extensions
      end

      def installed?
        state == :installed
      end

      def enqueued?
        state == :enqueued
      end

      def failed?
        state == :failed
      end

      def ready_to_enqueue?
        state == :none
      end

      def downloaded?
        download_state == :downloaded
      end

      def download_ready?
        download_state == :none
      end

      def has_post_install_message?
        !post_install_message.empty?
      end

      def ignorable_dependency?(dep)
        dep.type == :development || dep.name == @name
      end

      # Checks installed dependencies against spec's dependencies to make
      # sure needed dependencies have been installed.
      def dependencies_installed?(installed_specs)
        dependencies.all? {|d| installed_specs.include? d.name }
      end

      # For pure Ruby gems, we can install without waiting for dependencies
      # since there's no extconf.rb that might require them at build time.
      def can_install_without_deps?
        !has_native_ext
      end

      # Represents only the non-development dependencies, the ones that are
      # itself and are in the total list.
      def dependencies
        @dependencies ||= all_dependencies.reject {|dep| ignorable_dependency? dep }
      end

      # Represents all dependencies
      def all_dependencies
        @spec.dependencies
      end

      def to_s
        "#<#{self.class} #{full_name} (#{state}) dl:#{download_state}>"
      end

      private

      def detect_native_extensions
        return false unless @spec.respond_to?(:extensions)
        extensions = @spec.extensions
        extensions.is_a?(Array) ? extensions.any? : false
      rescue
        false
      end
    end

    def self.call(*args, **kwargs)
      new(*args, **kwargs).call
    end

    attr_reader :size

    def initialize(installer, all_specs, size, standalone, force, local: false, skip: nil)
      @installer = installer
      @size = size
      @standalone = standalone
      @force = force
      @local = local
      @specs = all_specs.map {|s| SpecInstallation.new(s) }
      @specs.each do |spec_install|
        if skip.include?(spec_install.name)
          spec_install.state = :installed
          spec_install.download_state = :downloaded
        end
      end if skip
      @spec_set = all_specs
      @rake = @specs.find {|s| s.name == "rake" unless s.installed? }
      @progress = ProgressReporter.new
    end

    def call
      if @rake
        do_install(@rake, 0)
      end

      # Phase 1: Download ALL gems in parallel
      download_all_gems

      # Phase 2: Install gems (extract + finalize inline per gem)
      # Native ext gems are prioritized when detected so compilation
      # starts ASAP and overlaps with pure Ruby gem installation.
      install_all_gems

      handle_error if failed_specs.any?
      @specs
    ensure
      worker_pool&.stop
      @download_pool&.stop
    end

    private

    def failed_specs
      @specs.select(&:failed?)
    end

    # Download all gems in parallel - no dependency ordering needed for downloads.
    # This is the key insight from tenderlove: downloading is pure I/O and can
    # happen for ALL gems simultaneously, regardless of dependency relationships.
    #
    # OPTIMIZATION (from uv's preparer.rs): Sort downloads by estimated size
    # descending so large gems start downloading first. This reduces tail
    # latency - by the time small gems finish, large ones are already in progress.
    # Gems with native extensions tend to be larger, so we prioritize those.
    def download_all_gems
      downloadable = @specs.reject {|s| s.installed? || s.failed? }
      return if downloadable.empty?

      # Sort: native extension gems first (tend to be larger), then by name
      # for deterministic ordering. This ensures large downloads start early.
      downloadable.sort_by! {|s| [s.has_native_ext ? 0 : 1, s.name] }

      @progress.start_phase(:download, downloadable.size)
      spinner_thread = start_spinner_thread

      download_size = [@size, downloadable.size].min
      download_size = [download_size, 8].max if download_size > 1 # At least 8 download threads

      if download_size > 1
        download_pool = Bundler::Worker.new(download_size, "Parallel Downloader", lambda {|spec_install, worker_num|
          Bundler.ui.silence { do_download(spec_install) }
          spec_install
        })

        downloadable.each do |spec_install|
          spec_install.download_state = :enqueued
          @progress.item_start(spec_install.name, spec_install.spec.version, download_label_for(spec_install))
          download_pool.enq spec_install
        end

        downloadable.size.times do
          download_pool.deq
        end

        download_pool.stop
      else
        downloadable.each do |spec_install|
          @progress.item_start(spec_install.name, spec_install.spec.version, download_label_for(spec_install))
          do_download(spec_install)
        end
      end

      stop_spinner_thread(spinner_thread)
      @progress.finish_phase
    end

    def download_label_for(spec_install)
      source = spec_install.spec.source
      if source.is_a?(Source::Git)
        "git checkout"
      elsif source.is_a?(Source::Path)
        "local"
      else
        "fetching"
      end
    end

    def do_download(spec_install)
      return if spec_install.installed? || spec_install.download_state == :downloaded

      source = spec_install.spec.source
      if source.respond_to?(:download)
        begin
          source.download(
            spec_install.spec,
            force: @force,
            local: @local
          )
          spec_install.download_state = :downloaded
          done = source.is_a?(Source::Git) ? "checked out" : "fetched"
          @progress.item_done(spec_install.name, done)
        rescue => e
          Bundler.ui.debug "Download warning for #{spec_install.name}: #{e.message}"
          spec_install.download_state = :downloaded # Mark as "attempted"
          @progress.item_done(spec_install.name, "cached")
        end
      else
        spec_install.download_state = :downloaded
        @progress.item_done(spec_install.name, "local")
      end
    end

    def install_all_gems
      installable = @specs.reject {|s| s.installed? || s.failed? }
      return if installable.empty?

      @progress.start_phase(:install, installable.size)
      @install_spinner_thread = start_spinner_thread

      if @size > 1
        install_with_worker
      else
        install_serially
      end

      stop_spinner_thread(@install_spinner_thread)
      @install_spinner_thread = nil
      @progress.finish_phase
    end

    def install_with_worker
      enqueue_specs
      process_specs until finished_installing?
    end

    def install_serially
      until finished_installing?
        raise "failed to find a spec to enqueue while installing serially" unless spec_install = @specs.find(&:ready_to_enqueue?)
        spec_install.state = :enqueued
        do_install(spec_install, 0)
      end
    end

    def worker_pool
      @worker_pool ||= Bundler::Worker.new @size, "Parallel Installer", lambda {|spec_install, worker_num|
        Bundler.ui.silence { do_install(spec_install, worker_num) }
      }
    end

    def do_install(spec_install, worker_num)
      detail = spec_install.has_native_ext ? "compiling native extensions" : "installing"
      @progress.item_start(spec_install.name, spec_install.spec.version, detail)

      Plugin.hook(Plugin::Events::GEM_BEFORE_INSTALL, spec_install)

      # Try the phased path: extract to temp dir, then finalize.
      # This is crash-safe (temp dir is cleaned up on failure) and
      # lets us detect native extensions from the real spec.
      gem_installer = Bundler::GemInstaller.new(
        spec_install.spec, @installer, @standalone, worker_num, @force, @local
      )
      extract_result = gem_installer.extract_from_spec

      if extract_result
        # Detect native extensions from the REAL spec (not LazySpecification).
        # LazySpecification doesn't have #extensions, so detect_native_extensions
        # may return false. The real Gem::Specification from the .gem package
        # has the correct extensions list.
        _temp_dir, _installer, real_spec = extract_result
        if !spec_install.has_native_ext && real_spec.respond_to?(:extensions) &&
            real_spec.extensions.is_a?(Array) && real_spec.extensions.any?
          spec_install.has_native_ext = true
        end

        success, message = gem_installer.finalize_from_spec(extract_result, spec_install.has_native_ext)
        if success
          spec_install.state = :installed
          spec_install.post_install_message = message unless message.nil?
        else
          spec_install.error = "#{message}\n\n#{require_tree_for_spec(spec_install.spec)}"
          spec_install.state = :failed
        end
      else
        # extract_from_spec returns nil when gem is already installed or
        # source doesn't support phased install (git, path). Fall back
        # to the traditional install path.
        success, message = gem_installer.install_from_spec
        if success
          spec_install.state = :installed
          spec_install.post_install_message = message unless message.nil?
        else
          spec_install.error = "#{message}\n\n#{require_tree_for_spec(spec_install.spec)}"
          spec_install.state = :failed
        end
      end

      done_detail = spec_install.has_native_ext ? "compiled" : "installed"
      done_detail = "failed" if spec_install.failed?
      @progress.item_done(spec_install.name, done_detail)

      Plugin.hook(Plugin::Events::GEM_AFTER_INSTALL, spec_install)
      spec_install
    end

    # Dequeue a spec and save its post-install message and then enqueue the
    # remaining specs.
    # Some specs might've had to wait til this spec was installed to be
    # processed so the call to `enqueue_specs` is important after every
    # dequeue.
    def process_specs
      worker_pool.deq
      enqueue_specs
    end

    def finished_installing?
      @specs.all? do |spec|
        return true if spec.failed?
        spec.installed?
      end
    end

    def handle_error
      errors = failed_specs.map(&:error)
      if exception = errors.find {|e| e.is_a?(Bundler::BundlerError) }
        raise exception
      end
      raise Bundler::InstallError, errors.join("\n\n")
    end

    def require_tree_for_spec(spec)
      tree = @spec_set.what_required(spec)
      t = String.new("In #{File.basename(SharedHelpers.default_gemfile)}:\n")
      tree.each_with_index do |s, depth|
        t << "  " * depth.succ << s.name
        unless tree.last == s
          t << %( was resolved to #{s.version}, which depends on)
        end
        t << %(\n)
      end
      t
    end

    # Keys in the remains hash represent uninstalled gems specs.
    # We enqueue all gem specs that do not have any dependencies.
    # Later we call this lambda again to install specs that depended on
    # previously installed specifications. We continue until all specs
    # are installed.
    #
    # OPTIMIZATION: Pure Ruby gems (no native extensions) can be installed
    # without waiting for their dependencies, since they don't run any
    # code during installation. Only gems with native extensions need
    # their dependencies installed first (for extconf.rb).
    #
    # PRIORITY: Native extension gems are enqueued first so that
    # compilation starts ASAP and overlaps with pure Ruby gem installation.
    def enqueue_specs
      installed_specs = {}
      @specs.each do |spec|
        next unless spec.installed?
        installed_specs[spec.name] = true
      end

      # Collect enqueueable specs, prioritizing native ext gems
      native_ext_ready = []
      pure_ruby_ready = []

      @specs.each do |spec|
        next unless spec.ready_to_enqueue?

        if spec.has_native_ext
          # Native extension gem: must wait for dependencies
          if spec.dependencies_installed?(installed_specs)
            native_ext_ready << spec
          end
        else
          # Pure Ruby gem: install immediately, no need to wait for deps
          pure_ruby_ready << spec
        end
      end

      # Enqueue native ext gems first so compilation starts early
      (native_ext_ready + pure_ruby_ready).each do |spec|
        spec.state = :enqueued
        worker_pool.enq spec
      end
    end

    # Start a background thread that ticks the spinner animation.
    def start_spinner_thread
      return nil unless @progress.tty
      Thread.new do
        loop do
          sleep 0.15
          @progress.tick
        rescue
          break
        end
      end
    end

    def stop_spinner_thread(thread)
      return unless thread
      thread.kill
      thread.join(0.5)
    end
  end
end
