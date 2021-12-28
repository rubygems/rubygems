# frozen_string_literal: true
require 'rubygems/command'

class Gem::Ext::CargoBuilder < Gem::Ext::Builder
  class DylibNotFoundError < StandardError
    def initialize(dir)
      super <<~MSG
        Dynamic library not found for Rust extension (in #{dir})

        Make sure you set "crate-type" in Cargo.toml to "cdylib"
      MSG
    end
  end

  TemplateScope = Struct.new(:extension_name) do
    def binding
      super
    end
  end

  attr_reader :spec

  def initialize(spec)
    @spec = spec
  end

  def build(extension, dest_path, results, args=[], lib_dir=nil, cargo_dir=Dir.pwd)
    build_crate(extension, dest_path, results, args, lib_dir, cargo_dir)
    dylib = validate_cargo_build!(dest_path)
    FileUtils.cp(dylib, dylib.gsub(File.basename(dylib), "#{spec.name}.#{RbConfig::CONFIG['DLEXT']}"))

    finalize_directory(extension, dest_path, results, args, lib_dir, cargo_dir)
    results
  end

  private

  def build_crate(extension, dest_path, results, args, lib_dir, cargo_dir)
    begin
      manifest = File.join(cargo_dir, 'Cargo.toml')

      given_ruby_static = ENV['RUBY_STATIC']

      ENV['RUBY_STATIC'] = 'true' if ruby_static? && !given_ruby_static
      cargo = ENV.fetch('CARGO', 'cargo')

      cmd = []
      cmd += [cargo, "rustc", "--release"]
      cmd += ["--target-dir", dest_path]
      cmd += ["--manifest-path", manifest]
      cmd += Gem::Command.build_args
      cmd += [*cargo_rustc_args(dest_path)]

      self.class.run cmd, results, self.class.class_name, cargo_dir
      results
    ensure
      ENV['RUBY_STATIC'] = given_ruby_static
    end
  end

  def validate_cargo_build!(dir)
    dylibs = Dir.glob(File.join(dir, 'release', "lib#{spec.name}.{so,dylib}"))

    raise DylibNotFoundError.new(dir) if dylibs.empty?

    dylibs.first
  end

  def dynamic_linker_flags
    return if RbConfig::CONFIG['build_os'] == 'mingw32'

    RbConfig::CONFIG['DLDFLAGS'].strip
  end

  def cargo_rustc_args(dest_dir)
    [
      '--lib',
      '--',
      '-C',
      "link-args=#{dynamic_linker_flags}",
      '-C',
      "link-arg=#{RbConfig::CONFIG['LIBRUBYARG']}",
      '-C',
      "link-arg=-Wl,-rpath,#{RbConfig::CONFIG['libdir']}",
    ]
  end

  def ruby_static?
    ENV.key?('RUBY_STATIC') || RbConfig::CONFIG['ENABLE_SHARED'] == 'no'
  end

  # Copied from ExtConfBuilder
  def finalize_directory(extension, dest_path, results, args, lib_dir, extension_dir)
    require 'fileutils'
    require 'tempfile'

    destdir = ENV["DESTDIR"]

    begin
      tmp_dest = Dir.mktmpdir(".gem.", extension_dir)

      # Some versions of `mktmpdir` return absolute paths, which will break make
      # if the paths contain spaces. However, on Ruby 1.9.x on Windows, relative
      # paths cause all C extension builds to fail.
      #
      # As such, we convert to a relative path unless we are using Ruby 1.9.x on
      # Windows. This means that when using Ruby 1.9.x on Windows, paths with
      # spaces do not work.
      #
      # Details: https://github.com/rubygems/rubygems/issues/977#issuecomment-171544940
      tmp_dest_relative = get_relative_path(tmp_dest.clone, extension_dir)

      ENV["DESTDIR"] = nil

      if tmp_dest_relative
        full_tmp_dest = File.join(extension_dir, tmp_dest_relative)

        # TODO remove in RubyGems 3
        if Gem.install_extension_in_lib and lib_dir
          FileUtils.mkdir_p lib_dir
          entries = Dir.entries(full_tmp_dest) - %w[. ..]
          entries = entries.map {|entry| File.join full_tmp_dest, entry }
          FileUtils.cp_r entries, lib_dir, :remove_destination => true
        end

        FileUtils::Entry_.new(full_tmp_dest).traverse do |ent|
          destent = ent.class.new(dest_path, ent.rel)
          destent.exist? or FileUtils.mv(ent.path, destent.path)
        end
      end
    ensure
      ENV["DESTDIR"] = destdir
      FileUtils.rm_rf tmp_dest if tmp_dest
    end
  end

  def get_relative_path(path, base)
    path[0..base.length - 1] = '.' if path.start_with?(base)
    path
  end
end
