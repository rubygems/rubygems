# frozen_string_literal: true

require "rubygems/installer"
require_relative "io_trace"

module Bundler
  class RubyGemsGemInstaller < Gem::Installer
    # Detect clonefile support (macOS APFS copy-on-write)
    CLONEFILE_SUPPORTED = begin
      if RUBY_PLATFORM =~ /darwin/
        require "fiddle"
        true
      else
        false
      end
    rescue LoadError
      false
    end

    def check_executable_overwrite(filename)
      # Bundler needs to install gems regardless of binstub overwriting
    end

    def install
      pre_install_checks

      run_pre_install_hooks

      spec.loaded_from = spec_file

      # Completely remove any previous gem files
      IOTrace.trace(:file_write, "strict_rm_rf gem_dir: #{gem_dir}") { strict_rm_rf gem_dir }
      IOTrace.trace(:file_write, "strict_rm_rf extension_dir: #{spec.extension_dir}") { strict_rm_rf spec.extension_dir }

      SharedHelpers.filesystem_access(gem_dir, :create) do
        FileUtils.mkdir_p gem_dir, mode: 0o755
      end

      IOTrace.trace(:file_write, "extract_files: #{spec.name} -> #{gem_dir}") do
        SharedHelpers.filesystem_access(gem_dir, :write) do
          extract_files
        end
      end

      if spec.extensions.any?
        IOTrace.trace(:file_write, "build_extensions: #{spec.name}") { build_extensions }
      end
      write_build_info_file
      run_post_build_hooks

      SharedHelpers.filesystem_access(bin_dir, :write) do
        generate_bin
      end

      generate_plugins

      IOTrace.trace(:file_write, "write_spec: #{spec.name}") { write_spec }

      IOTrace.trace(:file_write, "write_cache_file: #{spec.name}") do
        SharedHelpers.filesystem_access("#{gem_home}/cache", :write) do
          write_cache_file
        end
      end

      say spec.post_install_message unless spec.post_install_message.nil?

      run_post_install_hooks

      spec
    end

    if Bundler.rubygems.provides?("< 3.5")
      def pre_install_checks
        super
      rescue Gem::FilePermissionError
        # Ignore permission checks in RubyGems. Instead, go on, and try to write
        # for real. We properly handle permission errors when they happen.
        nil
      end
    end

    def ensure_writable_dir(dir)
      super
    rescue Gem::FilePermissionError
      # Ignore permission checks in RubyGems. Instead, go on, and try to write
      # for real. We properly handle permission errors when they happen.
      nil
    end

    def generate_plugins
      return unless Gem::Installer.method_defined?(:generate_plugins, false)

      latest = Gem::Specification.stubs_for(spec.name).first
      return if latest && latest.version > spec.version

      ensure_writable_dir @plugins_dir

      if spec.plugins.empty?
        remove_plugins_for(spec, @plugins_dir)
      else
        regenerate_plugins_for(spec, @plugins_dir)
      end
    end

    if Bundler.rubygems.provides?("< 3.5.19")
      def generate_bin_script(filename, bindir)
        bin_script_path = File.join bindir, formatted_program_filename(filename)

        Gem.open_file_with_lock(bin_script_path) do
          require "fileutils"
          FileUtils.rm_f bin_script_path # prior install may have been --no-wrappers

          File.open(bin_script_path, "wb", 0o755) do |file|
            file.write app_script_text(filename)
            file.chmod(options[:prog_mode] || 0o755)
          end
        end

        verbose bin_script_path

        generate_windows_script filename, bindir
      end
    end

    def build_jobs
      Bundler.settings[:jobs] || super
    end

    def build_extensions
      extension_cache_path = options[:bundler_extension_cache_path]
      extension_dir = spec.extension_dir
      unless extension_cache_path && extension_dir
        prepare_extension_build(extension_dir)
        return super
      end

      build_complete = SharedHelpers.filesystem_access(extension_cache_path.join("gem.build_complete"), :read, &:file?)
      if build_complete && !options[:force]
        SharedHelpers.filesystem_access(File.dirname(extension_dir)) do |p|
          FileUtils.mkpath p
        end
        SharedHelpers.filesystem_access(extension_cache_path) do
          fast_cp_r extension_cache_path.to_s, extension_dir.to_s
        end
      else
        prepare_extension_build(extension_dir)
        super
        SharedHelpers.filesystem_access(extension_cache_path.parent, &:mkpath)
        SharedHelpers.filesystem_access(extension_cache_path) do
          fast_cp_r extension_dir.to_s, extension_cache_path.to_s
        end
      end
    end

    def spec
      if Bundler.rubygems.provides?("< 3.3.12") # RubyGems implementation rescues and re-raises errors before 3.3.12 and we don't want that
        @package.spec
      else
        super
      end
    end

    def gem_checksum
      Checksum.from_gem_package(@package)
    end

    private

    # Fast directory copy using macOS clonefile (APFS copy-on-write),
    # falling back to hardlinks, then regular copy.
    # This follows uv's hierarchical fallback: clone -> hardlink -> copy
    def fast_cp_r(src, dest)
      if CLONEFILE_SUPPORTED && IOTrace.trace(:file_copy, "try_clonefile: #{src} -> #{dest}") { try_clonefile(src, dest) }
        return
      end

      if IOTrace.trace(:file_link, "try_hardlink_tree: #{src} -> #{dest}") { try_hardlink_tree(src, dest) }
        return
      end

      IOTrace.trace(:file_copy, "FileUtils.cp_r: #{src} -> #{dest}") { FileUtils.cp_r(src, dest) }
    end

    # Try macOS clonefile syscall for instant copy-on-write
    def try_clonefile(src, dest)
      return false unless CLONEFILE_SUPPORTED
      # Use system cp -c for clone on macOS (uses clonefile under the hood)
      system("cp", "-cR", src.to_s, dest.to_s, out: File::NULL, err: File::NULL)
    rescue
      false
    end

    # Try to hardlink all files from src to dest tree
    def try_hardlink_tree(src, dest)
      return false unless File.directory?(src)

      FileUtils.mkdir_p(dest) unless File.exist?(dest)

      Dir.each_child(src) do |entry|
        src_path = File.join(src, entry)
        dest_path = File.join(dest, entry)

        if File.directory?(src_path)
          return false unless try_hardlink_tree(src_path, dest_path)
        else
          begin
            FileUtils.ln(src_path, dest_path)
          rescue Errno::EXDEV, Errno::ENOTSUP, Errno::EPERM
            return false
          end
        end
      end

      true
    rescue
      false
    end

    def prepare_extension_build(extension_dir)
      SharedHelpers.filesystem_access(extension_dir, :create) do
        FileUtils.mkdir_p extension_dir
      end
    end

    def strict_rm_rf(dir)
      # OPTIMIZATION: Use a single lstat call instead of File.exist? + Dir.empty? + File.stat
      # which results in 3+ stat syscalls. We use lstat to avoid following symlinks.
      begin
        st = File.lstat(dir)
      rescue Errno::ENOENT
        return # doesn't exist
      end

      return unless st.directory?

      # Only check for empty if it's a directory (Dir.empty? is a single getdents call)
      return if Dir.empty?(dir)

      parent = File.dirname(dir)
      parent_st = File.stat(parent)

      if parent_st.world_writable? && !parent_st.sticky?
        raise InsecureInstallPathError.new(spec.full_name, dir)
      end

      begin
        FileUtils.remove_entry_secure(dir)
      rescue StandardError => e
        raise unless File.exist?(dir)

        raise DirectoryRemovalError.new(e, "Could not delete previous installation of `#{dir}`")
      end
    end
  end
end
