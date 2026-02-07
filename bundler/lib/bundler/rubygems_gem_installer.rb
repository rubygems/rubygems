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

      Gem::Specification.add_spec(spec)

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
        # Cache hit: copy compiled extensions from global cache (no compilation)
        SharedHelpers.filesystem_access(File.dirname(extension_dir)) do |p|
          FileUtils.mkpath p
        end
        SharedHelpers.filesystem_access(extension_cache_path) do
          fast_cp_r extension_cache_path.to_s, extension_dir.to_s
        end
      else
        # Cache miss: need to compile. Reset spec registry so extconf.rb
        # can find dependencies (only pay this cost when actually compiling).
        Gem::Specification.reset
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

    # Single-pass extraction: read the .gem tar once, extracting both the
    # gemspec (from metadata.gz) and the contents (from data.tar.gz).
    # Skips checksum verification — we trust compact index checksums.
    # Returns the Gem::Specification parsed from metadata.
    def self.single_pass_extract(gem_path, dest_dir)
      require "rubygems/package"
      spec = nil

      File.open(gem_path, "rb") do |io|
        Gem::Package::TarReader.new(io) do |reader|
          reader.each do |entry|
            case entry.full_name
            when "metadata.gz"
              spec = Gem::Specification.from_yaml(Gem::Util.gunzip(entry.read))
            when /\Ametadata\z/
              spec = Gem::Specification.from_yaml(entry.read)
            when "data.tar.gz"
              extract_data_tar_gz(entry, dest_dir)
            end
          end
        end
      end

      raise Gem::Package::FormatError, "No metadata found in #{gem_path}" unless spec
      spec
    end

    # Extract a data.tar.gz entry from a .gem tar into dest_dir.
    # Primary path: pipe raw gzipped bytes to system `tar` (zero Ruby
    # decompression — all heavy work happens in native code).
    # Fallback: Ruby-based extraction with IO.copy_stream.
    def self.extract_data_tar_gz(io, dest_dir)
      FileUtils.mkdir_p(dest_dir, mode: 0o755) unless File.directory?(dest_dir)

      # Pipe raw data.tar.gz bytes to system tar for native extraction.
      # The io is a TarReader::Entry containing the gzipped tar — we send
      # the raw bytes and let native tar handle gzip + extraction.
      begin
        IO.popen(["tar", "xzf", "-", "-C", dest_dir], "wb") do |tar_stdin|
          buf = String.new(capacity: 65536, encoding: Encoding::BINARY)
          begin
            loop do
              io.readpartial(65536, buf)
              tar_stdin.write(buf)
            end
          rescue EOFError
            # Normal end of tar entry
          end
        end
        return if $?.success?
      rescue Errno::ENOENT
        # tar command not found — fall through to Ruby path
      end

      # Fallback: Ruby-based extraction (e.g. Windows without tar)
      io.rewind
      ruby_extract_data_tar_gz(io, dest_dir)
    end

    # Pure Ruby extraction of data.tar.gz using IO.copy_stream for
    # minimal allocation overhead on the file-write path.
    def self.ruby_extract_data_tar_gz(io, dest_dir)
      dest_dir_prefix = File.expand_path(dest_dir) + "/"

      Gem::Package::TarReader.new(Zlib::GzipReader.new(io)) do |tar|
        tar.each do |entry|
          full_name = entry.full_name.sub(%r{\A\./}, "")
          next if full_name.empty? || full_name == "."

          destination = File.expand_path(File.join(dest_dir, full_name))
          unless destination.start_with?(dest_dir_prefix) || destination == File.expand_path(dest_dir)
            raise Gem::Package::PathError.new(full_name, dest_dir)
          end

          if entry.directory?
            FileUtils.mkdir_p(destination, mode: 0o755)
          elsif entry.file?
            FileUtils.mkdir_p(File.dirname(destination), mode: 0o755)
            File.open(destination, "wb") do |out|
              IO.copy_stream(tar.io, out, entry.header.size)
            end
            File.chmod(entry.header.mode & 0o777, destination) rescue nil
          elsif entry.header.typeflag == "2" # symlink
            File.symlink(entry.header.linkname, destination)
          end
        end
      end
    end

    # Populate gem_dir from source_dir (cache or temp), then finalize.
    # copy: true uses fast_cp_r (keeps source intact for cache reuse).
    # copy: false uses atomic_move (renames source to gem_dir).
    def finalize_without_extensions(source_dir, copy: false)
      place_gem_dir(source_dir, copy: copy)

      spec.loaded_from = spec_file

      write_build_info_file
      run_post_build_hooks

      SharedHelpers.filesystem_access(bin_dir, :write) do
        generate_bin
      end

      generate_plugins

      IOTrace.trace(:file_write, "write_spec: #{spec.name}") { write_spec }

      IOTrace.trace(:file_write, "write_cache_file: #{spec.name}") do
        SharedHelpers.filesystem_access("#{gem_home}/cache", :write) do
          fast_cache_gem
        end
      end

      say spec.post_install_message unless spec.post_install_message.nil?
      run_post_install_hooks

      spec
    end

    # Finalize a gem with native extensions.
    # Must wait for dependencies. Place files, build extensions, then finalize.
    def finalize_with_extensions(source_dir, copy: false)
      place_gem_dir(source_dir, copy: copy)

      spec.loaded_from = spec_file

      IOTrace.trace(:file_write, "build_extensions: #{spec.name}") { build_extensions }
      write_build_info_file
      run_post_build_hooks

      SharedHelpers.filesystem_access(bin_dir, :write) do
        generate_bin
      end

      generate_plugins

      IOTrace.trace(:file_write, "write_spec: #{spec.name}") { write_spec }

      IOTrace.trace(:file_write, "write_cache_file: #{spec.name}") do
        SharedHelpers.filesystem_access("#{gem_home}/cache", :write) do
          fast_cache_gem
        end
      end

      say spec.post_install_message unless spec.post_install_message.nil?
      run_post_install_hooks

      spec
    end

    private

    # Hardlink (or copy) the .gem file into GEM_HOME/cache/.
    # The .gem already exists in the download cache or global gem cache,
    # so a hardlink avoids duplicating hundreds of MB of data.
    def fast_cache_gem
      cache_file = File.join(gem_home, "cache", spec.file_name)
      return if File.exist?(cache_file)

      gem_path = @package.gem.path rescue nil
      return write_cache_file unless gem_path && File.exist?(gem_path)

      cache_dir = File.dirname(cache_file)
      FileUtils.mkdir_p(cache_dir) unless File.directory?(cache_dir)

      begin
        FileUtils.ln(gem_path, cache_file)
      rescue Errno::EXDEV, Errno::ENOTSUP, Errno::EPERM, Errno::EEXIST
        write_cache_file
      end
    end

    # Place extracted gem files into gem_dir.
    # copy: true → fast_cp_r from cache (keeps cache intact)
    # copy: false → atomic rename from temp dir
    def place_gem_dir(source_dir, copy: false)
      strict_rm_rf(gem_dir)
      strict_rm_rf(spec.extension_dir)

      if copy
        SharedHelpers.filesystem_access(File.dirname(gem_dir), :create) do |p|
          FileUtils.mkdir_p(p)
        end
        IOTrace.trace(:file_copy, "place_gem_dir: #{source_dir} -> #{gem_dir}") do
          fast_cp_r(source_dir, gem_dir)
        end
      else
        atomic_move(source_dir, gem_dir)
      end
    end

    # Fast directory copy: hardlinks first (pure Ruby, no subprocess),
    # then clonefile (subprocess), then regular copy.
    # Hardlinks are preferred because they avoid forking a process per gem.
    def fast_cp_r(src, dest)
      if try_hardlink_tree(src, dest)
        return
      end

      if CLONEFILE_SUPPORTED && try_clonefile(src, dest)
        return
      end

      FileUtils.cp_r(src, dest)
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

    # Atomic rename, falling back to FileUtils.mv for cross-device moves
    def atomic_move(src, dest)
      strict_rm_rf(dest)
      strict_rm_rf("#{dest.chomp('/')}.old") # clean up any leftover
      begin
        File.rename(src, dest)
      rescue Errno::EXDEV
        FileUtils.mv(src, dest)
      end
    end
  end
end
