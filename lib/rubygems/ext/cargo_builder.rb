# frozen_string_literal: true

require "rubygems/command"

# This class is used by rubygems to build Rust extensions. It is a thin-wrapper
# over the `cargo rustc` command which takes care of building Rust code in a way
# that Ruby can use.
class Gem::Ext::CargoBuilder < Gem::Ext::Builder
  attr_reader :spec

  def initialize(spec)
    @spec = spec
  end

  def build(_extension, dest_path, results, args = [], lib_dir = nil, cargo_dir = Dir.pwd)
    build_crate(dest_path, results, args, cargo_dir)
    ext_path = rename_cdylib_for_ruby_compatibility(dest_path)
    finalize_directory(ext_path, dest_path, lib_dir, cargo_dir)
    results
  end

  private

  def build_crate(dest_path, results, args, cargo_dir)
    manifest = File.join(cargo_dir, "Cargo.toml")

    given_ruby_static = ENV["RUBY_STATIC"]

    ENV["RUBY_STATIC"] = "true" if ruby_static? && !given_ruby_static

    cargo = ENV.fetch("CARGO", "cargo")

    cmd = []
    cmd += [cargo, "rustc"]
    cmd += ["--target-dir", dest_path]
    cmd += ["--manifest-path", manifest]
    cmd += [*cargo_rustc_args(dest_path)]
    cmd += Gem::Command.build_args
    cmd += args

    self.class.run cmd, results, self.class.class_name, cargo_dir
    results
  ensure
    ENV["RUBY_STATIC"] = given_ruby_static
  end

  def cargo_rustc_args(_dest_dir)
    [
      "--lib",
      "--release",
      "--locked",
      "--",
      *rustc_dynamic_linker_flags,
    ]
  end

  def ruby_static?
    return true if %w[1 true].include?(ENV["RUBY_STATIC"])

    RbConfig::CONFIG["ENABLE_SHARED"] == "no"
  end

  # Copied from ExtConfBuilder
  def finalize_directory(ext_path, dest_path, lib_dir, extension_dir)
    require "fileutils"
    require "tempfile"

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

      if tmp_dest_relative
        full_tmp_dest = File.join(extension_dir, tmp_dest_relative)

        # TODO: remove in RubyGems 3
        if Gem.install_extension_in_lib && lib_dir
          FileUtils.mkdir_p lib_dir
          FileUtils.cp_r ext_path, lib_dir, remove_destination: true
        end

        FileUtils::Entry_.new(full_tmp_dest).traverse do |ent|
          destent = ent.class.new(dest_path, ent.rel)
          destent.exist? || FileUtils.mv(ent.path, destent.path)
        end
      end
    ensure
      FileUtils.rm_rf tmp_dest if tmp_dest
    end
  end

  def get_relative_path(path, base)
    path[0..base.length - 1] = "." if path.start_with?(base)
    path
  end

  # Ruby expects the dylib to follow a file name convention for loading
  def rename_cdylib_for_ruby_compatibility(dest_path)
    dylib_path = validate_cargo_build!(dest_path)
    dlext_name = "#{spec.name}.#{RbConfig::CONFIG['DLEXT']}"
    new_name = dylib_path.gsub(File.basename(dylib_path), dlext_name)
    FileUtils.cp(dylib_path, new_name)
    new_name
  end

  def validate_cargo_build!(dir)
    dylib_path = File.join(dir, "release", "lib#{spec.name}.#{so_ext}")

    raise DylibNotFoundError, dir unless File.exist?(dylib_path)

    dylib_path
  end

  def rustc_dynamic_linker_flags
    args = RbConfig::CONFIG.fetch("DLDFLAGS", "").strip.split(" ")

    args.flat_map {|a| ldflag_to_link_mofifier(a) }.compact
  end

  def ldflag_to_link_mofifier(arg)
    flag = arg[0..1]
    val = arg[2..-1]

    case flag
    when "-L" then ["-L", "native=#{val}"]
    when "-l" then ["-l", val.to_s]
    when "-F" then ["-l", "framework=#{val}"]
    when "-W" then ["-C", "link_arg=#{arg}"]
    end
  end

  # We have to basically reimplement RbConfig::CONFIG['SOEXT'] here to support
  # Ruby < 2.5
  #
  # @see https://github.com/ruby/ruby/blob/c87c027f18c005460746a74c07cd80ee355b16e4/configure.ac#L3185
  def so_ext
    return RbConfig::CONFIG["SOEXT"] if RbConfig::CONFIG.key?("SOEXT")

    case RbConfig::CONFIG["target_os"]
    when /^darwin/i                        then "dylib"
    when /^(cygwin|msys|mingw)/i, /djgpp/i then "dll"
    else                                        "so"
    end
  end

  # Error raised when no cdylib artificat was created
  class DylibNotFoundError < StandardError
    def initialize(dir)
      super <<~MSG
        Dynamic library not found for Rust extension (in #{dir})

        Make sure you set "crate-type" in Cargo.toml to "cdylib"
      MSG
    end
  end
end
