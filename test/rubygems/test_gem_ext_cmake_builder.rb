# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/ext'

class TestGemExtCmakeBuilder < Gem::TestCase

  def setup
    super

    # Details: https://github.com/rubygems/rubygems/issues/1270#issuecomment-177368340
    skip "CmakeBuilder doesn't work on Windows." if Gem.win_platform?

    _, status = Open3.capture2e('cmake')

    skip 'cmake not present' unless status.success?

    @ext = File.join @tempdir, 'ext'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_self_build
    File.open File.join(@ext, 'CMakeLists.txt'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.6)
project(self_build NONE)
install (FILES test.txt DESTINATION bin)
      eo_cmake
    end

    FileUtils.touch File.join(@ext, 'test.txt')

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, @dest_path, output
    end

    output = output.join "\n"

    assert_match \
      %r{^cmake \. -DCMAKE_INSTALL_PREFIX=#{Regexp.escape @dest_path}}, output
    assert_match %r{#{Regexp.escape @ext}}, output
    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
    assert_match %r{test\.txt}, output
  end

  def test_self_build_fail
    output = []

    error = assert_raises Gem::InstallError do
      Dir.chdir @ext do
        Gem::Ext::CmakeBuilder.build nil, @dest_path, output
      end
    end

    output = output.join "\n"

    shell_error_msg = %r{(CMake Error: .*)}
    sh_prefix_cmake = "cmake . -DCMAKE_INSTALL_PREFIX="

    assert_match 'cmake failed', error.message

    assert_match %r{^#{sh_prefix_cmake}#{Regexp.escape @dest_path}}, output
    assert_match %r{#{shell_error_msg}}, output
  end

  def test_self_build_has_makefile
    File.open File.join(@ext, 'Makefile'), 'w' do |makefile|
      makefile.puts "all:\n\t@echo ok\ninstall:\n\t@echo ok"
    end

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, @dest_path, output
    end

    output = output.join "\n"

    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
  end

  def test_self_build_erb
    File.open File.join(@ext, 'CMakeLists.txt.erb'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.6)
project(self_build NONE)
install (FILES <%= RbConfig.expand(RbConfig::MAKEFILE_CONFIG['RUBY_SO_NAME']) %>.txt DESTINATION bin)
      eo_cmake
    end

    ruby_so_name = "#{RbConfig.expand(RbConfig::MAKEFILE_CONFIG['RUBY_SO_NAME'])}"
    FileUtils.touch File.join(@ext, "#{ruby_so_name}.txt")

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, @dest_path, output
    end

    output = output.join "\n"

    assert_match \
      %r{^cmake \. -DCMAKE_INSTALL_PREFIX=#{Regexp.escape @dest_path}}, output
    assert_match %r{#{Regexp.escape @ext}}, output
    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
    assert_match "#{ruby_so_name}.txt", output
  end

  def test_self_build_erb_has_cmakelists
    File.open File.join(@ext, 'CMakeLists.txt.erb'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.6)
project(self_build NONE)
install (FILES <%= RbConfig.expand(RbConfig::MAKEFILE_CONFIG['RUBY_SO_NAME']) %>.txt DESTINATION bin)
      eo_cmake
    end

    File.open File.join(@ext, 'CMakeLists.txt'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.6)
project(self_build NONE)
install (FILES test.txt DESTINATION bin)
      eo_cmake
    end

    FileUtils.touch File.join(@ext, 'test.txt')

    output = []

    Dir.chdir @ext do
      Gem::Ext::CmakeBuilder.build nil, @dest_path, output
    end

    output = output.join "\n"

    assert_match \
      %r{^cmake \. -DCMAKE_INSTALL_PREFIX=#{Regexp.escape @dest_path}}, output
    assert_match %r{#{Regexp.escape @ext}}, output
    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
    assert_match %r{test\.txt}, output
  end

  def test_self_build_args
    File.open File.join(@ext, 'CMakeLists.txt'), 'w' do |cmakelists|
      cmakelists.write <<-eo_cmake
cmake_minimum_required(VERSION 2.6)
project(self_build NONE)
if (CMAKE_BUILD_TYPE MATCHES Test)
  install (FILES test.txt DESTINATION bin)
else()
  install (FILES test_fail.txt DESTINATION bin)
endif()
      eo_cmake
    end

    FileUtils.touch File.join(@ext, 'test.txt')
    FileUtils.touch File.join(@ext, 'test_fail.txt')

    output = []

    Dir.chdir @ext do
      begin
        build_args_keep = Gem::Command.build_args
        Gem::Command.build_args = %w[-DCMAKE_BUILD_TYPE=Test]
        Gem::Ext::CmakeBuilder.build nil, @dest_path, output
      ensure
        Gem::Command.build_args = build_args_keep
      end
    end

    output = output.join "\n"

    assert_match \
      %r{^cmake \. -DCMAKE_INSTALL_PREFIX=#{Regexp.escape @dest_path}}, output
    assert_match %r{#{Regexp.escape @ext}}, output
    assert_contains_make_command '', output
    assert_contains_make_command 'install', output
    assert_match %r{test\.txt}, output
  end

end
