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
    if Gem.java_platform?
      pend("failing on jruby")
    end

    if vc_windows? && !nmake_found?
      pend("test_class_build skipped - nmake not found")
    end

    File.open File.join(@ext, "extconf.rb"), "w" do |extconf|
      extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
    end

    output = []

    result = Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], nil, @ext

    assert_same result, output

    assert_match(/^current directory:/, output[0])
    assert_match(/^#{Regexp.quote(Gem.ruby)}.* extconf.rb/, output[1])
    assert_equal "creating Makefile\n", output[2]
    assert_match(/^current directory:/, output[3])
    assert_contains_make_command "clean", output[4]
    assert_contains_make_command "", output[7]
    assert_contains_make_command "install", output[10]
    assert_empty Dir.glob(File.join(@ext, "siteconf*.rb"))
    assert_empty Dir.glob(File.join(@ext, ".gem.*"))
  end

  def test_class_build_rbconfig_make_prog
    if Gem.java_platform?
      pend("failing on jruby")
    end

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

    if Gem.java_platform?
      pend("failing on jruby")
    end

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
    error = assert_raise Gem::InstallError do
      Gem::Ext::ExtConfBuilder.make @ext, ["output"], @ext
    end

    assert_equal "Makefile not found", error.message
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

  def test_class_build_with_lib_placement_warning
    if Gem.java_platform?
      pend("failing on jruby")
    end

    if vc_windows? && !nmake_found?
      pend("test_class_build_with_lib_placement_warning skipped - nmake not found")
    end

    # Set up a gem-like directory structure
    gem_dir = File.join @tempdir, "test_gem"
    ext_dir = File.join gem_dir, "ext", "extension"
    lib_dir = File.join gem_dir, "lib"

    FileUtils.mkdir_p ext_dir
    FileUtils.mkdir_p lib_dir

    File.open File.join(ext_dir, "extconf.rb"), "w" do |extconf|
      extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
    end

    # Mock the install_extension_in_lib setting to true
    original_setting = Gem.install_extension_in_lib
    Gem.configuration.install_extension_in_lib = true

    # Capture stderr for warning
    require "stringio"
    stderr = StringIO.new
    original_stderr = $stderr
    $stderr = stderr

    output = []

    begin
      result = Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], lib_dir, ext_dir

      # Restore stderr
      $stderr = original_stderr

      warning_output = stderr.string
      assert_includes warning_output, "Gem 'test_gem' is installing native extensions in /lib directory"
      assert_includes warning_output, "Consider moving extensions to /ext directory for better organization"
      assert_includes warning_output, "Set install_extension_in_lib: true in your .gemrc to maintain current behavior"
    ensure
      # Restore original setting
      Gem.configuration.install_extension_in_lib = original_setting
      $stderr = original_stderr
    end
  end

  def test_class_build_without_lib_placement_warning_when_false
    if Gem.java_platform?
      pend("failing on jruby")
    end

    if vc_windows? && !nmake_found?
      pend("test_class_build_without_lib_placement_warning_when_false skipped - nmake not found")
    end

    # Set up a gem-like directory structure
    gem_dir = File.join @tempdir, "test_gem"
    ext_dir = File.join gem_dir, "ext", "extension"
    lib_dir = File.join gem_dir, "lib"

    FileUtils.mkdir_p ext_dir
    FileUtils.mkdir_p lib_dir

    File.open File.join(ext_dir, "extconf.rb"), "w" do |extconf|
      extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
    end

    # Mock the install_extension_in_lib setting to false
    original_setting = Gem.install_extension_in_lib
    Gem.configuration.install_extension_in_lib = false

    # Capture stderr for warning
    require "stringio"
    stderr = StringIO.new
    original_stderr = $stderr
    $stderr = stderr

    output = []

    begin
      result = Gem::Ext::ExtConfBuilder.build "extconf.rb", @dest_path, output, [], lib_dir, ext_dir

      # Restore stderr
      $stderr = original_stderr

      warning_output = stderr.string
      refute_includes warning_output, "Gem 'test_gem' is installing native extensions in /lib directory"
    ensure
      # Restore original setting
      Gem.configuration.install_extension_in_lib = original_setting
      $stderr = original_stderr
    end
  end

  def test_detect_gem_name_from_path
    # Test with standard gem structure
    path = "/path/to/test_gem/ext/extension"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_equal "test_gem", gem_name

    # Test with nested structure
    path = "/path/to/nested/test_gem/ext/extension"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_equal "test_gem", gem_name

    # Test with no ext directory
    path = "/path/to/test_gem/lib"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_nil gem_name

    # Test with ext at root
    path = "/ext/extension"
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_nil gem_name

    # Test with empty path
    path = ""
    gem_name = Gem::Ext::ExtConfBuilder.detect_gem_name_from_path(path)
    assert_nil gem_name
  end
end
