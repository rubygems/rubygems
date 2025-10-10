# frozen_string_literal: true

require_relative "helper"
require "rubygems/ext"

class TestGemExtExtConfBuilder < Gem::TestCase
  def setup
    super

    @ext = File.join @tempdir, "ext"
    @dest_path = File.join @tempdir, "prefix"

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_class_build
    if vc_windows? && !nmake_found?
      pend("test_class_build skipped - nmake not found")
    end

    File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
      extconf.puts "return if Gem.java_platform?"
      extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
    end

    output = []

    result = Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext

    assert_same result, output

    assert_match(/^current directory:/, output[0])
    assert_match(/^#{Regexp.quote(Gem.ruby)}.* extconf.rb/, output[1])

    if Gem.java_platform?
      assert_includes(output, "Skipping make for extconf.rb as no Makefile was found.")
    else
      assert_equal "creating Makefile\n", output[2]
      assert_match(/^current directory:/, output[3])
      assert_contains_make_command "clean", output[4]
      assert_contains_make_command "", output[7]
      assert_contains_make_command "install", output[10]
    end

    assert_empty Dir.glob(File.join(@ext, "siteconf*.rb"))
    assert_empty Dir.glob(File.join(@ext, ".gem.*"))
  end

  def test_class_build_rbconfig_make_prog
    configure_args do
      File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
        extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
      end

      output = []

      Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext

      assert_equal "creating Makefile\n", output[2]
      assert_contains_make_command "clean", output[4]
      assert_contains_make_command "", output[7]
      assert_contains_make_command "install", output[10]
    end
  end

  def test_class_build_env_make
    env_make = ENV.delete "make"
    ENV["make"] = nil

    env_large_make = ENV.delete "MAKE"
    ENV["MAKE"] = "anothermake"

    configure_args "" do
      File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
        extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
      end

      output = []

      assert_raise Gem::InstallError do
        Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext
      end

      assert_equal "creating Makefile\n",   output[2]
      assert_contains_make_command "clean", output[4]
    end
  ensure
    ENV["MAKE"] = env_large_make
    ENV["make"] = env_make
  end

  def test_class_build_extconf_fail
    if vc_windows? && !nmake_found?
      pend("test_class_build_extconf_fail skipped - nmake not found")
    end

    File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
      extconf.puts "require 'mkmf'"
      extconf.puts "have_library 'nonexistent' or abort 'need libnonexistent'"
      extconf.puts "create_makefile 'foo'"
    end

    output = []

    error = assert_raise Gem::InstallError do
      Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext
    end

    assert_equal "extconf failed, exit code 1", error.message

    assert_match(/^#{Regexp.quote(Gem.ruby)}.* extconf.rb/, output[1])
    assert_match(File.join(@dest_path, "mkmf.log"), output[4])
    assert_includes(output, "To see why this extension failed to compile, please check the mkmf.log which can be found here:\n")

    assert_path_exist File.join @dest_path, "mkmf.log"
  end

  def test_class_build_extconf_success_without_warning
    if vc_windows? && !nmake_found?
      pend("test_class_build_extconf_fail skipped - nmake not found")
    end

    File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
      extconf.puts "require 'mkmf'"
      extconf.puts "File.open('mkmf.log', 'w'){|f| f.write('a')}"
      extconf.puts "create_makefile 'foo'"
    end

    output = []

    Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext

    refute_includes(output, "To see why this extension failed to compile, please check the mkmf.log which can be found here:\n")

    assert_path_exist File.join @dest_path, "mkmf.log"
  end

  def test_class_build_unconventional
    if vc_windows? && !nmake_found?
      pend("test_class_build skipped - nmake not found")
    end

    File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
      extconf.puts <<-'EXTCONF'
include RbConfig

ruby =
  if ENV['RUBY'] then
    ENV['RUBY']
  else
    ruby_exe = "#{CONFIG['RUBY_INSTALL_NAME']}#{CONFIG['EXEEXT']}"
    File.join CONFIG['bindir'], ruby_exe
  end

open 'Makefile', 'w' do |io|
  io.write <<-Makefile
clean: ruby
all: ruby
install: ruby

ruby:
\t#{ruby} -e0

  Makefile
end
      EXTCONF
    end

    output = []

    Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext

    assert_contains_make_command "clean", output[4]
    assert_contains_make_command "", output[7]
    assert_contains_make_command "install", output[10]
    assert_empty Dir.glob(File.join(@ext, "siteconf*.rb"))
  end

  def test_class_make
    if vc_windows? && !nmake_found?
      pend("test_class_make skipped - nmake not found")
    end

    output = []
    makefile_path = File.join(@ext, "Makefile")
    File.open makefile_path, "w" do |makefile|
      makefile.puts "# π"
      makefile.puts "RUBYARCHDIR = $(foo)$(target_prefix)"
      makefile.puts "RUBYLIBDIR = $(bar)$(target_prefix)"
      makefile.puts "clean:"
      makefile.puts "all:"
      makefile.puts "install:"
    end

    Gem::Ext::ExtConfBuilder.make @ext, output, @ext

    assert_contains_make_command "clean", output[1]
    assert_contains_make_command "", output[4]
    assert_contains_make_command "install", output[7]
  end

  def test_class_make_no_Makefile
    error = assert_raise Gem::Ext::Builder::NoMakefileError do
      Gem::Ext::ExtConfBuilder.make @ext, ["output"], @ext
    end

    assert_match(/No Makefile found/, error.message)
  end

  def configure_args(args = nil)
    configure_args = RbConfig::CONFIG["configure_args"]
    RbConfig::CONFIG["configure_args"] = args if args

    yield
  ensure
    if configure_args
      RbConfig::CONFIG["configure_args"] = configure_args
    else
      RbConfig::CONFIG.delete "configure_args"
    end
  end

  def test_install_extension_in_lib_with_wrapper_file_when_enabled
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    # Mock the install_extension_in_lib setting
    Gem.stub(:install_extension_in_lib, true) do
      # Create a mock extension file
      extension_file = File.join(@ext, "test_extension.#{RbConfig::CONFIG["DLEXT"]}")
      File.write(extension_file, "fake extension content")
      
      # Mock the build method to test wrapper creation
      lib_dir = File.join(@dest_path, "lib")
      FileUtils.mkdir_p(lib_dir)
      
      # Test the wrapper file creation
      entries = [extension_file]
      gem_name = "test_gem"
      
      Gem::Ext::ExtConfBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
      
      # Verify wrapper file was created
      wrapper_path = File.join(lib_dir, "test_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
      assert_path_exist wrapper_path
      
      # Verify wrapper content
      wrapper_content = File.read(wrapper_path)
      assert_includes wrapper_content, "DEPRECATED: Gem 'test_gem'"
      assert_includes wrapper_content, "require_relative \"../ext/test_extension.#{RbConfig::CONFIG["DLEXT"]}\""
    end
  end

  def test_install_extension_in_lib_with_wrapper_file_without_gem_name
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    lib_dir = File.join(@dest_path, "lib")
    FileUtils.mkdir_p(lib_dir)
    
    # Test that no wrapper is created when gem_name is nil
    extension_file = File.join(@ext, "test_extension.#{RbConfig::CONFIG["DLEXT"]}")
    File.write(extension_file, "fake extension content")
    
    entries = [extension_file]
    
    Gem::Ext::ExtConfBuilder.create_wrapper_files(lib_dir, @dest_path, entries, nil)
    
    # Verify no wrapper file was created
    wrapper_path = File.join(lib_dir, "test_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
    refute_path_exist wrapper_path
  end

  def test_install_extension_in_lib_detection_os
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    # Test different operative system extensions
    case RbConfig::CONFIG["host_os"]
    when /darwin|mac os/
      assert Gem::Ext::ExtConfBuilder.native_extension?("test.bundle")
      refute Gem::Ext::ExtConfBuilder.native_extension?("test.so")
    when /mswin|mingw|cygwin/
      assert Gem::Ext::ExtConfBuilder.native_extension?("test.dll")
      refute Gem::Ext::ExtConfBuilder.native_extension?("test.so")
    else
      assert Gem::Ext::ExtConfBuilder.native_extension?("test.so")
      refute Gem::Ext::ExtConfBuilder.native_extension?("test.dll")
    end
    
    # Test non-extension files
    refute Gem::Ext::ExtConfBuilder.native_extension?("test.rb")
    refute Gem::Ext::ExtConfBuilder.native_extension?("test.txt")
  end

  def test_install_extension_in_lib_with_wrapper_file_detects_gem_name_from_path
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    # Test path detection
    path = "/path/to/gem_name/ext/extension_name"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_equal "gem_name", gem_name
    
    # Test path without ext directory
    path = "/path/to/gem_name/lib/extension_name"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_nil gem_name
    
    # Test path with multiple ext directories
    path = "/path/to/gem_name/ext/subdir/ext/extension_name"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_equal "subdir", gem_name
  end

  def test_extension_in_lib_with_wrapper_file_content_file_structure
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    lib_dir = File.join(@dest_path, "lib")
    FileUtils.mkdir_p(lib_dir)
    
    extension_name = "test_extension.#{RbConfig::CONFIG["DLEXT"]}"
    gem_name = "test_gem"
    wrapper_path = File.join(lib_dir, "#{extension_name}.rb")
    
    Gem::Ext::ExtConfBuilder.create_wrapper_file(wrapper_path, extension_name, gem_name)
    
    # Verify wrapper file exists
    assert_path_exist wrapper_path
    
    # Verify content structure
    content = File.read(wrapper_path)
    assert_includes content, "# frozen_string_literal: true"
    assert_includes content, "# DEPRECATED: This extension is loaded from lib/ directory"
    assert_includes content, "warn \"DEPRECATED: Gem 'test_gem'"
    assert_includes content, "require_relative \"../ext/#{extension_name}\""
    assert_includes content, "This wrapper will be removed in a future RubyGems version"
  end

  def test_extension_in_lib_wont_wrap_non_native_extensions
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    lib_dir = File.join(@dest_path, "lib")
    FileUtils.mkdir_p(lib_dir)
    
    # Create non-native extension files
    ruby_file = File.join(@ext, "test_helper.rb")
    File.write(ruby_file, "class TestHelper; end")
    
    text_file = File.join(@ext, "README.txt")
    File.write(text_file, "Read me")
    
    entries = [ruby_file, text_file]
    gem_name = "test_gem"
    
    Gem::Ext::ExtConfBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
    
    # Verify no wrapper files were created
    refute_path_exist File.join(lib_dir, "test_helper.rb.rb")
    refute_path_exist File.join(lib_dir, "README.txt.rb")
  end

  def test_extension_in_lib_will_wrap_native_extensions_only
    skip "Wrapper functionality not available" unless Gem.respond_to?(:install_extension_in_lib)
    
    lib_dir = File.join(@dest_path, "lib")
    FileUtils.mkdir_p(lib_dir)
    
    # Create mixed content: native extension + Ruby file
    extension_file = File.join(@ext, "test_extension.#{RbConfig::CONFIG["DLEXT"]}")
    File.write(extension_file, "fake extension content")
    
    ruby_file = File.join(@ext, "test_wrapper.rb")
    File.write(ruby_file, "class TestWrapper; end")
    
    entries = [extension_file, ruby_file]
    gem_name = "test_gem"
    
    Gem::Ext::ExtConfBuilder.create_wrapper_files(lib_dir, @dest_path, entries, gem_name)
    
    # Verify wrapper file was created only for native extension
    wrapper_path = File.join(lib_dir, "test_extension.#{RbConfig::CONFIG["DLEXT"]}.rb")
    assert_path_exist wrapper_path
    
    # Verify no wrapper for Ruby file
    refute_path_exist File.join(lib_dir, "test_helper.rb.rb")
  end
end
