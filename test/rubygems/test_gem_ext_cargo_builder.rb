# frozen_string_literal: true

require_relative "helper"
require "rubygems/ext"
require "open3"
begin
  require "fiddle"
rescue LoadError
end

class TestGemExtCargoBuilder < Gem::TestCase
  def setup
    super

    @rust_envs = {
      "CARGO_HOME" => ENV.fetch("CARGO_HOME", File.join(@orig_env["HOME"], ".cargo")),
      "RUSTUP_HOME" => ENV.fetch("RUSTUP_HOME", File.join(@orig_env["HOME"], ".rustup")),
    }
  end

  def setup_rust_gem(name)
    @ext = File.join(@tempdir, "ext")
    @dest_path = File.join(@tempdir, "prefix")
    @fixture_dir = Pathname.new(File.expand_path("test_gem_ext_cargo_builder/#{name}/", __dir__))

    FileUtils.mkdir_p @dest_path
    FileUtils.cp_r(@fixture_dir.to_s, @ext)
  end

  def test_build_cdylib
    skip_unsupported_platforms!
    setup_rust_gem "rust_ruby_example"

    output = []

    Dir.chdir @ext do
      ENV.update(@rust_envs)
      builder = Gem::Ext::CargoBuilder.new
      builder.build "Cargo.toml", @dest_path, output
    end

    output = output.join "\n"
    bundle = File.join(@dest_path, "rust_ruby_example.#{RbConfig::CONFIG["DLEXT"]}")

    assert_match(/Finished/, output)
    assert_match(/release/, output)
    assert_ffi_handle bundle, "Init_rust_ruby_example"
  rescue StandardError => e
    pp output if output

    raise(e)
  end

  def test_rubygems_cfg_passed_to_rustc
    skip_unsupported_platforms!
    setup_rust_gem "rust_ruby_example"
    version_slug = Gem::VERSION.tr(".", "_")
    output = []

    replace_in_rust_file("src/lib.rs", "rubygems_x_x_x", "rubygems_#{version_slug}")

    Dir.chdir @ext do
      ENV.update(@rust_envs)
      builder = Gem::Ext::CargoBuilder.new
      builder.build "Cargo.toml", @dest_path, output
    end

    output = output.join "\n"
    bundle = File.join(@dest_path, "rust_ruby_example.#{RbConfig::CONFIG["DLEXT"]}")

    assert_ffi_handle bundle, "hello_from_rubygems"
    assert_ffi_handle bundle, "hello_from_rubygems_version"
    refute_ffi_handle bundle, "should_never_exist"
  rescue StandardError => e
    pp output if output

    raise(e)
  end

  def test_build_fail
    skip_unsupported_platforms!
    setup_rust_gem "rust_ruby_example"

    FileUtils.rm(File.join(@ext, "src/lib.rs"))

    error = assert_raise(Gem::InstallError) do
      Dir.chdir @ext do
        ENV.update(@rust_envs)
        builder = Gem::Ext::CargoBuilder.new
        builder.build "Cargo.toml", @dest_path, []
      end
    end

    assert_match(/cargo\s.*\sfailed/, error.message)
  end

  def test_full_integration
    skip_unsupported_platforms!
    setup_rust_gem "rust_ruby_example"

    require "open3"

    Dir.chdir @ext do
      require "tmpdir"

      env_for_subprocess = @rust_envs.merge("GEM_HOME" => Gem.paths.home)
      gem = [env_for_subprocess, *ruby_with_rubygems_in_load_path, File.expand_path("../../exe/gem", __dir__)]

      Dir.mktmpdir("rust_ruby_example") do |dir|
        built_gem = File.expand_path(File.join(dir, "rust_ruby_example.gem"))
        Open3.capture2e(*gem, "build", "rust_ruby_example.gemspec", "--output", built_gem)
        Open3.capture2e(*gem, "install", "--verbose", "--local", built_gem, *ARGV)

        stdout_and_stderr_str, status = Open3.capture2e(env_for_subprocess, *ruby_with_rubygems_in_load_path, "-rrust_ruby_example", "-e", "puts 'Result: ' + RustRubyExample.reverse('hello world')")
        assert status.success?, stdout_and_stderr_str
        assert_match "Result: #{"hello world".reverse}", stdout_and_stderr_str
      end
    end
  end

  def test_custom_name
    skip_unsupported_platforms!
    setup_rust_gem "custom_name"

    Dir.chdir @ext do
      require "tmpdir"

      env_for_subprocess = @rust_envs.merge("GEM_HOME" => Gem.paths.home)
      gem = [env_for_subprocess, *ruby_with_rubygems_in_load_path, File.expand_path("../../exe/gem", __dir__)]

      Dir.mktmpdir("custom_name") do |dir|
        built_gem = File.expand_path(File.join(dir, "custom_name.gem"))
        Open3.capture2e(*gem, "build", "custom_name.gemspec", "--output", built_gem)
        Open3.capture2e(*gem, "install", "--verbose", "--local", built_gem, *ARGV)
      end

      stdout_and_stderr_str, status = Open3.capture2e(env_for_subprocess, *ruby_with_rubygems_in_load_path, "-rcustom_name", "-e", "puts 'Result: ' + CustomName.say_hello")

      assert status.success?, stdout_and_stderr_str
      assert_match "Result: Hello world!", stdout_and_stderr_str
    end
  end

  def test_linker_args
    orig_cc = RbConfig::MAKEFILE_CONFIG["CC"]
    RbConfig::MAKEFILE_CONFIG["CC"] = "clang"

    builder = Gem::Ext::CargoBuilder.new
    args = builder.send(:linker_args)

    assert args[1], "linker=clang"
    assert_nil args[2]
  ensure
    RbConfig::MAKEFILE_CONFIG["CC"] = orig_cc
  end

  def test_linker_args_with_options
    orig_cc = RbConfig::MAKEFILE_CONFIG["CC"]
    RbConfig::MAKEFILE_CONFIG["CC"] = "gcc -Wl,--no-undefined"

    builder = Gem::Ext::CargoBuilder.new
    args = builder.send(:linker_args)

    assert args[1], "linker=clang"
    assert args[3], "link-args=-Wl,--no-undefined"
  ensure
    RbConfig::MAKEFILE_CONFIG["CC"] = orig_cc
  end

  def test_linker_args_with_cachetools
    orig_cc = RbConfig::MAKEFILE_CONFIG["CC"]
    RbConfig::MAKEFILE_CONFIG["CC"] = "sccache clang"

    builder = Gem::Ext::CargoBuilder.new
    args = builder.send(:linker_args)

    assert args[1], "linker=clang"
    assert_nil args[2]
  ensure
    RbConfig::MAKEFILE_CONFIG["CC"] = orig_cc
  end

  def test_linker_args_with_cachetools_and_options
    orig_cc = RbConfig::MAKEFILE_CONFIG["CC"]
    RbConfig::MAKEFILE_CONFIG["CC"] = "ccache gcc -Wl,--no-undefined"

    builder = Gem::Ext::CargoBuilder.new
    args = builder.send(:linker_args)

    assert args[1], "linker=clang"
    assert args[3], "link-args=-Wl,--no-undefined"
  ensure
    RbConfig::MAKEFILE_CONFIG["CC"] = orig_cc
  end

  def test_extension_in_lib_with_wrapper_file_when_enabled
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    # Mock the install_extension_in_lib setting
    Gem.stub(:install_extension_in_lib, true) do
      # Create a mock Rust extension file
      extension_file = File.join(@ext, "test_rust_extension.#{RbConfig::CONFIG["DLEXT"]}")
      File.write(extension_file, "fake rust extension content")
      
      lib_dir = File.join(@dest_path, "lib")
      FileUtils.mkdir_p(lib_dir)
      
      # Test the wrapper file creation
      entries = [extension_file]
      gem_name = "test_rust_gem"
      
      Gem::Ext::CargoBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
      
      # Verify wrapper file was created
      wrapper_path = File.join(lib_dir, "test_rust_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
      assert_path_exist wrapper_path
      
      # Verify wrapper content and path to ext/
      wrapper_content = File.read(wrapper_path)
      assert_includes wrapper_content, "DEPRECATED: Gem 'test_rust_gem'"
      assert_includes wrapper_content, "require_relative \"../ext/test_rust_extension.#{RbConfig::CONFIG["DLEXT"]}\""
    end
  end

  def test_extension_in_lib_with_wrapper_file_when_disabled
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    # Mock the install_extension_in_lib setting to false
    Gem.stub(:install_extension_in_lib, false) do
      lib_dir = File.join(@dest_path, "lib")
      FileUtils.mkdir_p(lib_dir)
      
      extension_file = File.join(@ext, "test_extension.#{RbConfig::CONFIG["DLEXT"]}")
      File.write(extension_file, "fake extension content")
      
      entries = [extension_file]
      gem_name = "test_gem"
      
      # This should not create wrapper files when install_extension_in_lib is false
      # The wrapper creation is only called when install_extension_in_lib is true
      # So we're testing the integration point
      refute_path_exist File.join(lib_dir, "test_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
    end
  end

  def test_extension_in_lib_with_wrapper_file_when_enabled_with_nested_lib_directory
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    Gem.stub(:install_extension_in_lib, true) do
      # Test with nested lib directory structure (like cargo builder uses)
      nested_lib_dir = File.join(@dest_path, "lib", "nested")
      FileUtils.mkdir_p(nested_lib_dir)
      
      extension_file = File.join(@ext, "test_nested_extension.#{RbConfig::CONFIG["DLEXT"]}")
      File.write(extension_file, "fake nested extension content")
      
      entries = [extension_file]
      gem_name = "test_nested_gem"
      
      Gem::Ext::CargoBuilder.create_wrapper_files(nested_lib_dir, @dest_path, entries, gem_name)
      
      # Verify wrapper file was created in nested directory
      wrapper_path = File.join(nested_lib_dir, "test_nested_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
      assert_path_exist wrapper_path
      
      # Verify wrapper content points to correct ext/ location
      wrapper_content = File.read(wrapper_path)
      assert_includes wrapper_content, "require_relative \"../ext/test_nested_extension.#{RbConfig::CONFIG["DLEXT"]}\""
    end
  end

  def test_extension_in_lib_detection_os
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    lib_dir = File.join(@dest_path, "lib")
    FileUtils.mkdir_p(lib_dir)
    
    # Test operative system specific extension detection
    case RbConfig::CONFIG["host_os"]
    when /darwin|mac os/
      extension_file = File.join(@ext, "test_extension.bundle")
      expected_wrapper = "test_extension.bundle.rb"
    when /mswin|mingw|cygwin/
      extension_file = File.join(@ext, "test_extension.dll")
      expected_wrapper = "test_extension.dll.rb"
    else
      extension_file = File.join(@ext, "test_extension.so")
      expected_wrapper = "test_extension.so.rb"
    end
    
    File.write(extension_file, "fake extension content")
    
    entries = [extension_file]
    gem_name = "test_platform_gem"
    
    Gem::Ext::CargoBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
    
    # Verify wrapper file was created with correct extension
    wrapper_path = File.join(lib_dir, expected_wrapper)
    assert_path_exist wrapper_path
    
    # Verify wrapper content
    wrapper_content = File.read(wrapper_path)
    assert_includes wrapper_content, "DEPRECATED: Gem 'test_platform_gem'"
  end

  def test_extension_in_lib_with_wrapper_file_when_enabled_with_multiple_extensions
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    Gem.stub(:install_extension_in_lib, true) do
      lib_dir = File.join(@dest_path, "lib")
      FileUtils.mkdir_p(lib_dir)
      
      # Create multiple extension files
      extension1 = File.join(@ext, "extension1.#{RbConfig::CONFIG["DLEXT"]}")
      extension2 = File.join(@ext, "extension2.#{RbConfig::CONFIG["DLEXT"]}")
      extension3 = File.join(@ext, "extension3.#{RbConfig::CONFIG["DLEXT"]}")
      
      [extension1, extension2, extension3].each do |ext_file|
        File.write(ext_file, "fake extension content")
      end
      
      entries = [extension1, extension2, extension3]
      gem_name = "test_multi_gem"
      
      Gem::Ext::CargoBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
      
      # Verify all wrapper files were created
      assert_path_exist File.join(lib_dir, "extension1.#{RbConfig::CONFIG["DLEXT"]}.rb")
      assert_path_exist File.join(lib_dir, "extension2.#{RbConfig::CONFIG["DLEXT"]}.rb")
      assert_path_exist File.join(lib_dir, "extension3.#{RbConfig::CONFIG["DLEXT"]}.rb")
      
      # Verify wrapper content for each
      [extension1, extension2, extension3].each do |ext_file|
        extension_name = File.basename(ext_file)
        wrapper_path = File.join(lib_dir, "#{extension_name}.rb")
        wrapper_content = File.read(wrapper_path)
        assert_includes wrapper_content, "DEPRECATED: Gem 'test_multi_gem'"
        assert_includes wrapper_content, "require_relative \"../ext/#{extension_name}\""
      end
    end
  end

  private

  def skip_unsupported_platforms!
    pend "jruby not supported" if Gem.java_platform?
    pend "truffleruby not supported (yet)" if RUBY_ENGINE == "truffleruby"
    system(@rust_envs, "cargo", "-V", out: IO::NULL, err: [:child, :out])
    pend "cargo not present" unless $?.success?
    pend "ruby.h is not provided by ruby repo" if ruby_repo?
    pend "rust toolchain of mingw is broken" if mingw_windows?
  end

  def assert_ffi_handle(bundle, name)
    return unless defined?(Fiddle)

    dylib_handle = Fiddle.dlopen bundle
    assert_nothing_raised { dylib_handle[name] }
  ensure
    dylib_handle&.close
  end

  def refute_ffi_handle(bundle, name)
    return unless defined?(Fiddle)

    dylib_handle = Fiddle.dlopen bundle
    assert_raise { dylib_handle[name] }
  ensure
    dylib_handle&.close
  end

  def replace_in_rust_file(name, from, to)
    content = @fixture_dir.join(name).read.gsub(from, to)
    File.write(File.join(@ext, name), content)
  end
end
