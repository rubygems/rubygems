#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
Gem.manage_gems
require 'yaml'
require 'fileutils'
require 'test/insure_session'

class FunctionalTest < Test::Unit::TestCase
  def setup
    @gem_path = File.expand_path("bin/gem")
    lib_path = File.expand_path("lib")
    @ruby_options = "-I#{lib_path} -I."
  end

  def test_gem_help_options
    gem 'help options'
    assert_match(/Usage:/, @out)
    assert_status
  end

  def test_gem_help_commands
    gem 'help commands'
    assert_match(/gem install/, @out)
    assert_status
  end

  def test_gem_no_args_shows_help
    gem
    assert_match(/Usage:/, @out)
    assert_status 1
  end

  def test_environment
    gem 'environment'
    
    assert_match /VERSION:\s+\d+\.\d+$/, @out
    assert_match /INSTALLATION DIRECTORY:/, @out
    assert_match /GEM PATH:/, @out
    assert_match /REMOTE SOURCES:/, @out
    assert_status
  end

  def test_env_version
    gem 'environment version'
    assert_match /\d+\.\d+$/, @out
  end

  def test_env_gemdir
    gem 'environment gemdir'
    assert_equal Gem.dir, @out.chomp
  end

  def test_env_gempath
    gem 'environment gempath'
    assert_equal Gem.path, @out.chomp.split("\n")
  end

  def test_env_remotesources
    gem 'environment remotesources'
    assert_equal Gem::RemoteInstaller.new.get_cache_sources, @out.chomp.split("\n")
  end

  ONEDIR = "test/data/one"
  ONENAME = "one-0.0.1.gem"
  ONEGEM = "#{ONEDIR}/#{ONENAME}"

  def test_build
    FileUtils.rm_f ONEGEM
    # TODO: Remove -n
    Dir.chdir(ONEDIR) do
      gem "build one.gemspec"
    end
    assert File.exist?(ONEGEM), "Gem file (#{ONEGEM}) should exist"
    assert_match /Successfully built RubyGem/, @out
    assert_match /Name: one$/, @out
    assert_match /Version: 0.0.1$/, @out
    assert_match /File: #{ONENAME}/, @out
    spec = read_gem_file(ONEGEM)
    assert_equal "one", spec.name
    assert_equal "Test GEM One", spec.summary
  end

  def test_bogus_source_hoses_up_remote_install_but_gem_command_gives_decent_error_message
    @ruby_options << " -rtest/bogussources"
    gem "install asdf --remote"
    assert_match(/error/im, @err)
    assert_status 1
  end

  private

  def gem(options="")
    shell = Session::Shell.new
    command = "ruby #{@ruby_options} #{@gem_path} #{options}"
    puts "COMMAND: [#{command}]" if @verbose
    @out, @err = shell.execute command
    @status = shell.exit_status
    puts "STATUS:  [#{@status}]" if @verbose
    puts "OUTPUT:  [#{@out}]" if @verbose
    puts "ERROR:   [#{@err}]" if @verbose
    puts "PWD:     [#{Dir.pwd}]" if @verbose
    shell.close
  end

  def assert_status(expected_status=0)
    assert_equal expected_status, @status
  end

  def read_gem_file(filename)
    open(filename) { |f|
      while line = f.gets
	break if line == "__END__\n"
      end
      YAML.load(f)
    }
  end

end
