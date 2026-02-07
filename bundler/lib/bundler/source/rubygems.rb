# frozen_string_literal: true

require "rubygems/user_interaction"
require_relative "../io_trace"

module Bundler
  class Source
    class Rubygems < Source
      autoload :Remote, File.expand_path("rubygems/remote", __dir__)

      # Ask for X gems per API request
      API_REQUEST_SIZE = 100

      attr_accessor :remotes

      def initialize(options = {})
        @options = options
        @remotes = []
        @dependency_names = []
        @allow_remote = false
        @allow_cached = false
        @allow_local = options["allow_local"] || false
        @prefer_local = false
        @checksum_store = Checksum::Store.new

        Array(options["remotes"]).reverse_each {|r| add_remote(r) }

        @lockfile_remotes = @remotes if options["from_lockfile"]
      end

      def caches
        @caches ||= [cache_path, *Bundler.rubygems.gem_cache]
      end

      def prefer_local!
        @prefer_local = true
      end

      def local_only!
        @specs = nil
        @allow_local = true
        @allow_cached = false
        @allow_remote = false
      end

      def local_only?
        @allow_local && !@allow_remote
      end

      def local!
        return if @allow_local

        @specs = nil
        @allow_local = true
      end

      def remote!
        return if @allow_remote

        @specs = nil
        @allow_remote = true
      end

      def cached!
        # OPTIMIZATION: Check @allow_cached first to avoid redundant File.exist?
        # stat calls. cached! is called up to 3 times during definition setup
        # (setup_domain!, with_cache!, remotely!) and each call would stat the
        # cache directory unnecessarily.
        return if @allow_cached
        return unless File.exist?(cache_path)

        @specs = nil
        @allow_cached = true
      end

      def hash
        @remotes.hash
      end

      def eql?(other)
        other.is_a?(Rubygems) && other.credless_remotes == credless_remotes
      end

      alias_method :==, :eql?

      def include?(o)
        o.is_a?(Rubygems) && (o.credless_remotes - credless_remotes).empty?
      end

      def multiple_remotes?
        @remotes.size > 1
      end

      def no_remotes?
        @remotes.size == 0
      end

      def can_lock?(spec)
        return super unless multiple_remotes?
        include?(spec.source)
      end

      def options
        { "remotes" => @remotes.map(&:to_s) }
      end

      def self.from_lock(options)
        options["remotes"] = Array(options.delete("remote")).reverse
        new(options.merge("from_lockfile" => true))
      end

      def to_lock
        out = String.new("GEM\n")
        lockfile_remotes.reverse_each do |remote|
          out << "  remote: #{remote}\n"
        end
        out << "  specs:\n"
      end

      def to_s
        if remotes.empty?
          "locally installed gems"
        elsif @allow_remote && @allow_cached && @allow_local
          "rubygems repository #{remote_names}, cached gems or installed locally"
        elsif @allow_remote && @allow_local
          "rubygems repository #{remote_names} or installed locally"
        elsif @allow_remote
          "rubygems repository #{remote_names}"
        elsif @allow_cached && @allow_local
          "cached gems or installed locally"
        else
          "locally installed gems"
        end
      end

      def identifier
        if remotes.empty?
          "locally installed gems"
        else
          "rubygems repository #{remote_names}"
        end
      end
      alias_method :name, :identifier
      alias_method :to_gemfile, :identifier

      def specs
        @specs ||= begin
          # remote_specs usually generates a way larger Index than the other
          # sources, and large_idx.merge! small_idx is way faster than
          # small_idx.merge! large_idx.
          index = @allow_remote ? remote_specs.dup : Index.new
          index.merge!(cached_specs) if @allow_cached
          index.merge!(installed_specs) if @allow_local

          if @allow_local
            if @prefer_local
              index.merge!(default_specs)
            else
              # complete with default specs, only if not already available in the
              # index through remote, cached, or installed specs
              index.use(default_specs)
            end
          end

          index
        end
      end

      # Download a gem to the cache without installing it.
      # Returns the path to the cached .gem file, or nil if already installed.
      def download(spec, previous_spec: nil, force: false, local: false)
        if (spec.default_gem? && !cached_built_in_gem(spec, local: local)) || (installed?(spec) && !force)
          return nil # already available
        end

        path = fetch_gem_if_possible(spec, previous_spec)
        raise GemNotFound, "Could not find #{spec.file_name} for download" unless path

        # OPTIMIZATION: Update cached_gem memo so install() doesn't re-stat
        @cached_gem_memo ||= {}
        @cached_gem_memo[spec.full_name] = path

        path
      end

      # Check if a spec has native extensions that need compilation.
      def has_native_extensions?(spec)
        return false unless spec.respond_to?(:extensions)
        extensions = spec.extensions
        extensions.is_a?(Array) ? extensions.any? : false
      rescue
        false
      end

      def extension_cache_path(spec)
        # Prefer global XDG-based extension cache
        global_path = global_extension_cache_path(spec)
        return global_path if global_path

        # Fall back to per-source cache
        super
      end

      def install(spec, options = {})
        if (spec.default_gem? && !cached_built_in_gem(spec, local: options[:local])) || (installed?(spec) && !options[:force])
          return nil # no post-install message
        end

        # Use pre-downloaded gem if available, otherwise download now
        path = cached_gem(spec) || fetch_gem_if_possible(spec, options[:previous_spec])
        raise GemNotFound, "Could not find #{spec.file_name} for installation" unless path

        return if Bundler.settings[:no_install]

        install_path = rubygems_dir
        bin_path     = Bundler.system_bindir

        require_relative "../rubygems_gem_installer"

        installer = Bundler::RubyGemsGemInstaller.at(
          path,
          security_policy: Bundler.rubygems.security_policies[Bundler.settings["trust-policy"]],
          install_dir: install_path.to_s,
          bin_dir: bin_path.to_s,
          ignore_dependencies: true,
          wrappers: true,
          env_shebang: true,
          build_args: options[:build_args],
          bundler_extension_cache_path: extension_cache_path(spec)
        )

        if spec.remote
          s = begin
            installer.spec
          rescue Gem::Package::FormatError
            Bundler.rm_rf(path)
            raise
          rescue Gem::Security::Exception => e
            raise SecurityError,
             "The gem #{File.basename(path, ".gem")} can't be installed because " \
             "the security policy didn't allow it, with the message: #{e.message}"
          end

          spec.__swap__(s)
        end

        spec.source.checksum_store.register(spec, installer.gem_checksum)

        installed_spec = nil

        Gem.time("Installed #{spec.name} in", 0, true) do
          installed_spec = installer.install
        end

        spec.full_gem_path = installed_spec.full_gem_path
        spec.loaded_from = installed_spec.loaded_from
        spec.base_dir = installed_spec.base_dir

        spec.post_install_message
      end

      # Extract gem contents, using a global extracted cache to avoid
      # re-extracting on subsequent installs. Returns [source_dir, installer,
      # spec, from_cache] or nil if already installed.
      #
      # Cache layout:
      #   ~/.cache/gem/extracted/<full_name>/              extracted gem files
      #   ~/.cache/gem/extracted/<full_name>.spec.marshal   marshaled Gem::Specification
      #
      # Cache HIT:  0 .gem file reads — spec loaded from marshal
      # Cache MISS: 1 .gem file read  — single-pass extraction (spec + data.tar.gz)
      def extract_gem(spec, options = {})
        if (spec.default_gem? && !cached_built_in_gem(spec, local: options[:local])) || (installed?(spec) && !options[:force])
          return nil
        end

        gem_path = cached_gem(spec) || fetch_gem_if_possible(spec, nil)
        raise GemNotFound, "Could not find #{spec.file_name} for extraction" unless gem_path

        return nil if Bundler.settings[:no_install]

        require_relative "../rubygems_gem_installer"

        cache_dir = extracted_cache_path(spec)

        # CACHE HIT: spec + extracted files available from global cache
        if cache_dir && (cached_spec = load_cached_spec(cache_dir))
          installer = build_gem_installer(gem_path, spec, options, preloaded_spec: cached_spec)
          spec.__swap__(cached_spec) if spec.remote
          installer.pre_install_checks
          return [cache_dir, installer, spec, true]
        end

        # CACHE MISS: single-pass extract .gem → global cache
        if cache_dir
          real_spec = extract_to_global_cache(gem_path, cache_dir)
          installer = build_gem_installer(gem_path, spec, options, preloaded_spec: real_spec)
          spec.__swap__(real_spec) if spec.remote
          installer.pre_install_checks
          return [cache_dir, installer, spec, true]
        end

        # FALLBACK: no global cache path available (homeless user etc.)
        installer = build_gem_installer(gem_path, spec, options)
        if spec.remote
          s = installer.spec
          spec.__swap__(s)
        end
        installer.pre_install_checks
        temp_dir = "#{installer.gem_dir}.bundler-tmp"
        FileUtils.rm_rf(temp_dir)
        FileUtils.mkdir_p(temp_dir, mode: 0o755)
        original_gem_dir = installer.gem_dir
        installer.instance_variable_set(:@gem_dir, temp_dir)
        begin
          installer.send(:extract_files)
        ensure
          installer.instance_variable_set(:@gem_dir, original_gem_dir)
        end
        [temp_dir, installer, spec, false]
      end

      # Finalize a previously extracted gem: copy/move files to GEM_HOME,
      # write spec, generate binstubs, build native extensions.
      def finalize_gem(spec, extract_result, has_extensions, options = {})
        return nil unless extract_result

        source_dir, installer, spec, from_cache = extract_result

        installed_spec = if has_extensions
          installer.finalize_with_extensions(source_dir, copy: !!from_cache)
        else
          installer.finalize_without_extensions(source_dir, copy: !!from_cache)
        end

        spec.full_gem_path = installed_spec.full_gem_path
        spec.loaded_from = installed_spec.loaded_from
        spec.base_dir = installed_spec.base_dir

        spec.post_install_message
      end

      def cache(spec, custom_path = nil)
        cached_path = Bundler.settings[:cache_all_platforms] ? fetch_gem_if_possible(spec) : cached_gem(spec)
        raise GemNotFound, "Missing gem file '#{spec.file_name}'." unless cached_path
        return if File.dirname(cached_path) == Bundler.app_cache.to_s
        Bundler.ui.info "  * #{File.basename(cached_path)}"
        FileUtils.cp(cached_path, Bundler.app_cache(custom_path))
      rescue Errno::EACCES => e
        Bundler.ui.debug(e)
        raise InstallError, e.message
      end

      def cached_built_in_gem(spec, local: false)
        cached_path = cached_gem(spec)
        if cached_path.nil? && !local
          remote_spec = remote_specs.search(spec).first
          if remote_spec
            cached_path = fetch_gem(remote_spec)
            spec.remote = remote_spec.remote
          else
            Bundler.ui.warn "#{spec.full_name} is built in to Ruby, and can't be cached because your Gemfile doesn't have any sources that contain it."
          end
        end
        cached_path
      end

      def add_remote(source)
        uri = normalize_uri(source)
        @remotes.unshift(uri) unless @remotes.include?(uri)
      end

      def spec_names
        if dependency_api_available?
          remote_specs.spec_names
        else
          []
        end
      end

      def unmet_deps
        if dependency_api_available?
          remote_specs.unmet_dependency_names
        else
          []
        end
      end

      def remote_fetchers
        @remote_fetchers ||= remotes.to_h do |uri|
          remote = Source::Rubygems::Remote.new(uri)
          [remote, Bundler::Fetcher.new(remote)]
        end.freeze
      end

      def fetchers
        @fetchers ||= remote_fetchers.values.freeze
      end

      def double_check_for(unmet_dependency_names)
        return unless dependency_api_available?

        unmet_dependency_names = unmet_dependency_names.call
        unless unmet_dependency_names.nil?
          if api_fetchers.size <= 1
            # can't do this when there are multiple fetchers because then we might not fetch from _all_
            # of them
            unmet_dependency_names -= remote_specs.spec_names # avoid re-fetching things we've already gotten
          end
          return if unmet_dependency_names.empty?
        end

        Bundler.ui.debug "Double checking for #{unmet_dependency_names || "all specs (due to the size of the request)"} in #{self}"

        fetch_names(api_fetchers, unmet_dependency_names, remote_specs)

        specs.use remote_specs
      end

      def dependency_names_to_double_check
        names = []
        remote_specs.each do |spec|
          case spec
          when EndpointSpecification, Gem::Specification, StubSpecification, LazySpecification
            names.concat(spec.runtime_dependencies.map(&:name))
          when RemoteSpecification # from the full index
            return nil
          else
            raise "unhandled spec type (#{spec.inspect})"
          end
        end
        names
      end

      def dependency_api_available?
        @allow_remote && api_fetchers.any?
      end

      protected

      def remote_names
        remotes.map(&:to_s).join(", ")
      end

      def credless_remotes
        remotes.map(&method(:remove_auth))
      end

      def cached_gem(spec)
        # OPTIMIZATION: Memoize cached_gem lookups to avoid redundant File.exist?
        # stat calls. cached_gem is called from both download() and install()
        # for the same spec, plus indirectly from fetch_gem_if_possible.
        @cached_gem_memo ||= {}
        key = spec.full_name
        return @cached_gem_memo[key] if @cached_gem_memo.key?(key)

        global_cache_path = download_cache_path(spec)
        # Only add global_cache_path if not already present to avoid growing
        # the caches array on every call (causes extra File.exist? checks)
        caches << global_cache_path if global_cache_path && !caches.include?(global_cache_path)

        possibilities = caches.map {|p| package_path(p, spec) }
        result = IOTrace.trace(:file_stat, "cached_gem search: #{spec.name} (#{possibilities.size} paths)") do
          possibilities.find {|p| File.exist?(p) }
        end
        @cached_gem_memo[key] = result
      end

      def package_path(cache_path, spec)
        "#{cache_path}/#{spec.file_name}"
      end

      def normalize_uri(uri)
        uri = URINormalizer.normalize_suffix(uri.to_s)
        require_relative "../vendored_uri"
        uri = Gem::URI(uri)
        raise ArgumentError, "The source must be an absolute URI. For example:\n" \
          "source 'https://rubygems.org'" if !uri.absolute? || (uri.is_a?(Gem::URI::HTTP) && uri.host.nil?)
        uri
      end

      def remove_auth(remote)
        if remote.user || remote.password
          remote.dup.tap {|uri| uri.user = uri.password = nil }.to_s
        else
          remote.to_s
        end
      end

      def installed_specs
        @installed_specs ||= Index.build do |idx|
          specs = if Bundler.default_lockfile.file?
            names = Bundler::LockfileParser.new(Bundler.read_file(Bundler.default_lockfile.to_s)).specs.map(&:name).uniq
            Bundler.rubygems.installed_specs_for_names(names)
          else
            Bundler.rubygems.installed_specs
          end
          specs.reverse_each do |spec|
            spec.source = self
            next if spec.ignored?
            idx << spec
          end
        end
      end

      def default_specs
        @default_specs ||= Index.build do |idx|
          Bundler.rubygems.default_specs.each do |spec|
            spec.source = self
            idx << spec
          end
        end
      end

      def cached_specs
        @cached_specs ||= begin
          idx = Index.new

          IOTrace.trace(:dir_scan, "cached_specs Dir glob: #{cache_path}/*.gem") do
            Dir["#{cache_path}/*.gem"].each do |gemfile|
              s ||= Bundler.rubygems.spec_from_gem(gemfile)
              s.source = self
              idx << s
            end
          end

          idx
        end
      end

      def api_fetchers
        fetchers.select(&:api_fetcher?)
      end

      def remote_specs
        @remote_specs ||= Index.build do |idx|
          index_fetchers = fetchers - api_fetchers

          if index_fetchers.empty?
            fetch_names(api_fetchers, dependency_names, idx)
          else
            fetch_names(fetchers, nil, idx)
          end
        end
      end

      def fetch_names(fetchers, dependency_names, index)
        fetchers.each do |f|
          if dependency_names
            Bundler.ui.info "Fetching gem metadata from #{URICredentialsFilter.credential_filtered_uri(f.uri)}", Bundler.ui.debug?
            index.use f.specs_with_retry(dependency_names, self)
            Bundler.ui.info "" unless Bundler.ui.debug? # new line now that the dots are over
          else
            Bundler.ui.info "Fetching source index from #{URICredentialsFilter.credential_filtered_uri(f.uri)}"
            index.use f.specs_with_retry(nil, self)
          end
        end
      end

      def fetch_gem_if_possible(spec, previous_spec = nil)
        if spec.remote
          fetch_gem(spec, previous_spec)
        else
          cached_gem(spec)
        end
      end

      def fetch_gem(spec, previous_spec = nil)
        spec.fetch_platform

        # Check global cache first (shared across Ruby versions)
        global_path = global_gem_cache_path(spec)
        if global_path && IOTrace.trace(:file_stat, "fetch_gem global cache check: #{spec.name}") { File.exist?(global_path) }
          # Found in global cache - copy/link to local cache if needed
          local_cache = default_cache_path_for(rubygems_dir)
          local_path = package_path(local_cache, spec)
          unless File.exist?(local_path)
            SharedHelpers.filesystem_access(local_cache) {|p| FileUtils.mkdir_p(p) }
            begin
              FileUtils.ln(global_path, local_path)
            rescue Errno::EXDEV, Errno::ENOTSUP
              FileUtils.cp(global_path, local_path)
            end
          end
          return local_path
        end

        cache_path = download_cache_path(spec) || default_cache_path_for(rubygems_dir)
        gem_path = package_path(cache_path, spec)
        return gem_path if File.exist?(gem_path)

        SharedHelpers.filesystem_access(cache_path) do |p|
          FileUtils.mkdir_p(p)
        end
        download_gem(spec, cache_path, previous_spec)

        # Store in global cache for future Ruby versions
        if global_path = global_gem_cache_path(spec)
          unless File.exist?(global_path)
            SharedHelpers.filesystem_access(File.dirname(global_path)) {|p| FileUtils.mkdir_p(p) }
            begin
              FileUtils.ln(gem_path, global_path)
            rescue Errno::EXDEV, Errno::ENOTSUP
              FileUtils.cp(gem_path, global_path)
            end
          end
        end

        gem_path
      end

      def installed?(spec)
        # OPTIMIZATION: Memoize installed? checks. Each call to installation_missing?
        # does a File.directory? syscall. During install, installed? is called from
        # both download() and install() for every spec.
        @installed_memo ||= {}
        key = spec.full_name
        return @installed_memo[key] if @installed_memo.key?(key)

        result = IOTrace.trace(:file_stat, "installed? check: #{spec.name}") do
          installed_specs[spec].any? && !spec.installation_missing?
        end
        @installed_memo[key] = result
      end

      def rubygems_dir
        Bundler.bundle_path
      end

      def default_cache_path_for(dir)
        "#{dir}/cache"
      end

      def cache_path
        Bundler.app_cache
      end

      private

      def lockfile_remotes
        @lockfile_remotes || credless_remotes
      end

      # Returns path in the global gem cache (XDG_CACHE_HOME based).
      # This cache is shared across all Ruby versions since .gem files
      # are Ruby-version independent archives.
      def global_gem_cache_path(spec = nil)
        cache_home = if Gem.respond_to?(:cache_home)
          Gem.cache_home
        else
          ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache")
        end
        cache_dir = File.join(cache_home, "gem", "gems")
        return cache_dir unless spec
        File.join(cache_dir, spec.file_name)
      rescue
        nil
      end

      # Returns path in the global extension cache (XDG_CACHE_HOME based).
      # Extensions are ABI-dependent, so the cache is keyed by Ruby engine,
      # Ruby version, and platform.
      def global_extension_cache_path(spec)
        cache_home = if Gem.respond_to?(:cache_home)
          Gem.cache_home
        else
          ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache")
        end
        ruby_key = "#{Gem.ruby_engine}-#{RbConfig::CONFIG["ruby_version"]}"
        platform_key = Gem::Platform.local.to_s
        ext_dir = File.join(cache_home, "gem", "extensions", ruby_key, platform_key)
        Pathname.new(ext_dir).join(spec.full_name.to_s)
      rescue
        nil
      end

      # Returns path for the global extracted gem cache.
      # Extracted contents are Ruby-version independent (source files only;
      # compiled extensions are cached separately by global_extension_cache_path).
      def extracted_cache_path(spec)
        return nil unless (base = gem_cache_home)
        File.join(base, "extracted", spec.full_name)
      rescue
        nil
      end

      # Base directory for all global gem caches (~/.cache/gem/).
      def gem_cache_home
        @gem_cache_home ||= begin
          base = if Gem.respond_to?(:cache_home)
            Gem.cache_home
          else
            ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache")
          end
          File.join(base, "gem")
        end
      rescue
        nil
      end

      # Load a cached Gem::Specification from the extracted cache.
      # Returns nil on cache miss or any error.
      def load_cached_spec(cache_dir)
        marshal_path = "#{cache_dir}.spec.marshal"
        return nil unless File.exist?(marshal_path)
        return nil unless File.directory?(cache_dir)
        Marshal.load(File.binread(marshal_path))
      rescue
        nil
      end

      # Single-pass extract a .gem to the global cache.
      # Uses a PID-unique temp dir + atomic rename for process safety.
      def extract_to_global_cache(gem_path, cache_dir)
        temp_dir = "#{cache_dir}.tmp-#{Process.pid}"
        begin
          FileUtils.rm_rf(temp_dir)
          FileUtils.mkdir_p(temp_dir, mode: 0o755)

          real_spec = Bundler::RubyGemsGemInstaller.single_pass_extract(gem_path, temp_dir)

          # Atomic move to final cache location
          SharedHelpers.filesystem_access(File.dirname(cache_dir)) { |p| FileUtils.mkdir_p(p) }
          begin
            File.rename(temp_dir, cache_dir)
          rescue Errno::EEXIST, Errno::ENOTEMPTY
            # Another process won the race — use theirs
            FileUtils.rm_rf(temp_dir)
          rescue Errno::EXDEV
            FileUtils.mv(temp_dir, cache_dir)
          end

          # Persist spec for future cache hits (stored as sibling, not inside
          # the extracted dir, so fast_cp_r doesn't copy it to GEM_HOME)
          File.binwrite("#{cache_dir}.spec.marshal", Marshal.dump(real_spec))

          real_spec
        rescue => e
          FileUtils.rm_rf(temp_dir) rescue nil
          raise
        end
      end

      # Create a RubyGemsGemInstaller, optionally injecting a preloaded spec
      # to avoid opening the .gem file for verification.
      def build_gem_installer(gem_path, spec, options, preloaded_spec: nil)
        installer = Bundler::RubyGemsGemInstaller.at(
          gem_path,
          security_policy: Bundler.rubygems.security_policies[Bundler.settings["trust-policy"]],
          install_dir: rubygems_dir.to_s,
          bin_dir: Bundler.system_bindir.to_s,
          ignore_dependencies: true,
          wrappers: true,
          env_shebang: true,
          build_args: options[:build_args],
          bundler_extension_cache_path: extension_cache_path(spec)
        )

        if preloaded_spec
          # Inject spec into the package to prevent .gem file from being
          # opened for verification. The spec was already parsed during
          # single-pass extraction or loaded from marshal cache.
          installer.instance_variable_get(:@package).instance_variable_set(:@spec, preloaded_spec)
        end

        installer
      end

      # Checks if the requested spec exists in the global cache. If it does,
      # we copy it to the download path, and if it does not, we download it.
      #
      # @param  [Specification] spec
      #         the spec we want to download or retrieve from the cache.
      #
      # @param  [String] download_cache_path
      #         the local directory the .gem will end up in.
      #
      # @param  [Specification] previous_spec
      #         the spec previously locked
      #
      def download_gem(spec, download_cache_path, previous_spec = nil)
        uri = spec.remote.uri
        gem_remote_fetcher = remote_fetchers.fetch(spec.remote).gem_remote_fetcher

        IOTrace.trace(:http, "download_gem: #{spec.name} from #{uri}") do
          Gem.time("Downloaded #{spec.name} in", 0, true) do
            Bundler.rubygems.download_gem(spec, uri, download_cache_path, gem_remote_fetcher)
          end
        end
      end

      # Returns the global cache path of the calling Rubygems::Source object.
      #
      # Note that the Source determines the path's subdirectory. We use this
      # subdirectory in the global cache path so that gems with the same name
      # -- and possibly different versions -- from different sources are saved
      # to their respective subdirectories and do not override one another.
      #
      # @param  [Gem::Specification] specification
      #
      # @return [Pathname] The global cache path.
      #
      def download_cache_path(spec)
        return unless Bundler.settings[:global_gem_cache]
        return unless remote = spec.remote
        return unless cache_slug = remote.cache_slug

        Bundler.user_cache.join("gems", cache_slug)
      end

      def extension_cache_slug(spec)
        return unless remote = spec.remote
        remote.cache_slug
      end
    end
  end
end
