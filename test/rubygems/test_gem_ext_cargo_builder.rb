# frozen_string_literal: true
require_relative 'helper'
require 'rubygems/ext'

class TestGemExtCargoBuilder < Gem::TestCase
  def setup
    @orig_env = ENV.to_hash

    @rust_envs = {
      'CARGO_HOME' => File.join(File.expand_path('~'), '.cargo'),
    }

    system(@rust_envs, 'cargo', '-V', out: IO::NULL, err: [:child, :out])
    pend 'cargo not present' unless $?.success?

    super

    @ext = File.join @tempdir, 'ext'
    @src = File.join @ext, 'src'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @src
    FileUtils.mkdir_p @dest_path
  end

  def test_build
    File.open File.join(@ext, 'Cargo.toml'), 'w' do |cargo|
      cargo.write <<~TOML
        [package]
        name = "test"
        version = "0.1.0"

        [dependencies]
        rutie = "0.8.2"

        [lib]
        name = "rutie_ruby_example"
        crate-type = ["staticlib"]
      TOML
    end

    File.open File.join(@src, 'lib.rs'), 'w' do |main|
      main.write "fn main() {}"
      main.write <<~RUST
        #[macro_use]
        extern crate rutie;

        use rutie::{Class, Object, RString, VM};

        class!(RutieExample);

        methods!(
            RutieExample,
            _rtself,

            fn pub_reverse(input: RString) -> RString {
                let ruby_string = input.
                  map_err(|e| VM::raise_ex(e) ).
                  unwrap();

                RString::new_utf8(
                  &ruby_string.
                  to_string().
                  chars().
                  rev().
                  collect::<String>()
                )
            }
        );

        #[allow(non_snake_case)]
        #[no_mangle]
        pub extern "C" fn Init_rutie_ruby_example() {
            Class::new("RutieExample", None).define(|klass| {
                klass.def_self("reverse", pub_reverse);
            });
        }
      RUST
    end

    output = []

    Dir.chdir @ext do
      ENV.update(@rust_envs)
      spec = Gem::Specification.new 'rutie_ruby_example', '0.1.0'
      builder = Gem::Ext::CargoBuilder.new(spec)
      builder.build nil, @dest_path, output
    end

    output = output.join "\n"

    bundle = Dir["#{@dest_path}/gemext/*.{bundle,so}"].first

    require(bundle)

    assert_match RutieExample.reverse('hello'), 'olleh'

    assert_match "Compiling test v0.1.0 (#{@ext})", output
    assert_match "Finished release [optimized] target(s)", output
  rescue
    warn output.join("\n")
    raise
  end

  def test_build_fail
    output = []

    error = assert_raises Gem::InstallError do
      Dir.chdir @ext do
        ENV.update(@rust_envs)
        spec = Gem::Specification.new 'rutie_ruby_example', '0.1.0'
        builder = Gem::Ext::CargoBuilder.new(spec)
        builder.build nil, @dest_path, output
      end
    end

    output = output.join "\n"

    assert_match 'cargo failed', error.message
  end
end
