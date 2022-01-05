# frozen_string_literal: true
require_relative 'helper'
require 'rubygems/ext'

class TestGemExtCargoBuilder < Gem::TestCase
  def setup
    @orig_env = ENV.to_hash

    @rust_envs = {
      'CARGO_HOME' => File.join(@orig_env['HOME'], '.cargo'),
      'RUSTUP_HOME' => File.join(@orig_env['HOME'], '.rustup'),
    }

    system(@rust_envs, 'cargo', '-V', out: IO::NULL, err: [:child, :out])
    pend 'cargo not present' unless $?.success?

    super

    @ext = File.join(@tempdir, 'ext')
    @dest_path = File.join(@tempdir, 'prefix')
    @fixture_dir = Pathname.new(File.expand_path('../test_gem_ext_cargo_builder/rust_ruby_example/', __FILE__))

    FileUtils.mkdir_p @dest_path
    FileUtils.cp_r(@fixture_dir.to_s, @ext)
  end

  def test_build_staticlib
    skip_unsupported_platforms!

    content = @fixture_dir.join('Cargo.toml').read.gsub("cdylib", "staticlib")
    File.write(File.join(@ext, 'Cargo.toml'), content)

    output = []

    Dir.chdir @ext do
      ENV.update(@rust_envs)
      spec = Gem::Specification.new 'rust_ruby_example', '0.1.0'
      builder = Gem::Ext::CargoBuilder.new(spec)
      assert_raises(Gem::Ext::CargoBuilder::DylibNotFoundError) do
        builder.build nil, @dest_path, output
      end
    end
  end

  def test_build_cdylib
    skip_unsupported_platforms!

    output = []

    Dir.chdir @ext do
      ENV.update(@rust_envs)
      spec = Gem::Specification.new 'rust_ruby_example', '0.1.0'
      builder = Gem::Ext::CargoBuilder.new(spec)
      builder.build nil, @dest_path, output
    end

    output = output.join "\n"

    bundle = File.join(@dest_path, "release/rust_ruby_example.#{RbConfig::CONFIG['DLEXT']}")

    require(bundle)

    assert_match RustRubyExample.reverse('hello'), 'olleh'

    assert_match "Compiling rust_ruby_example v0.1.0 (#{@ext})", output
    assert_match "Finished release [optimized] target(s)", output
  rescue Exception => e
    pp output if output

    raise(e)
  end

  def test_build_fail
    skip_unsupported_platforms!

    output = []

    FileUtils.rm(File.join(@ext, 'src/lib.rs'))

    error = assert_raises Gem::InstallError do
      Dir.chdir @ext do
        ENV.update(@rust_envs)
        spec = Gem::Specification.new 'rust_ruby_example', '0.1.0'
        builder = Gem::Ext::CargoBuilder.new(spec)
        builder.build nil, @dest_path, output
      end
    end

    output = output.join "\n"

    assert_match 'cargo failed', error.message
  end

  def test_full_integration
    skip_unsupported_platforms!

    Dir.chdir @ext do
      require 'tmpdir'

      gem = [@rust_envs, *ruby_with_rubygems_in_load_path, File.expand_path("./../../../bin/gem", __FILE__)]

      Dir.mktmpdir("rust_ruby_example") do |dir|
        built_gem = File.expand_path(File.join(dir, "rust_ruby_example.gem"))
        Open3.capture2e *gem, "build", "rust_ruby_example.gemspec", "--output", built_gem
        Open3.capture2e *gem, "install", "--verbose", "--local", built_gem, *ARGV
      end

      stdout_and_stderr_str, status = Open3.capture2e(@rust_envs, *ruby_with_rubygems_in_load_path, "-rrust_ruby_example", "-e", "puts 'Result: ' + RustRubyExample.reverse('hello world')")

      assert status.success?, stdout_and_stderr_str
      assert_match "Result: #{"hello world".reverse}", stdout_and_stderr_str
    end
  end

  def skip_unsupported_platforms!
    pend "Rust extensions are not supported on jruby" if java_platform?
    pend "Pending support for truffleruby in Rust extensions" if RUBY_ENGINE == 'truffleruby'
  end
end
