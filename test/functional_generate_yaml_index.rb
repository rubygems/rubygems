#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'fileutils'
require 'test/insure_session'
require 'test/onegem'

# ====================================================================
class TestGenerateYamlIndex < Test::Unit::TestCase

  SERVER_DIR = 'test/temp/server'

  def setup
    @gyi_path = File.expand_path("bin/index_gem_repository.rb")
    @gem_path = File.expand_path("bin/gem")
    lib_path = File.expand_path("lib")
    @ruby_options = "-I#{lib_path} -I."
    @verbose = false
  end

  def test_build_gem
    OneGem.make(self)
  end

  def test_server_dir_initialize_really_works
    initialize_server_directory
    assert File.exist?(srvfile("gems"))
    assert File.exist?(srvfile("gems/one-0.0.1.gem"))
    assert ! File.exist?(srvfile("yaml"))
    assert ! File.exist?(srvfile("yaml.Z"))
    assert ! File.exist?(srvfile("quick"))
  end

  def test_generate_old_style_index
    initialize_server_directory

    generate_yaml_index("--directory #{SERVER_DIR} --no-quick")

    assert_equal '', @out
    assert_equal '', @err
    assert_equal 0, @status, "no status error"
    assert File.exist?(srvfile("yaml"))
    assert File.exist?(srvfile("yaml.Z"))
    assert ! File.exist?(srvfile("quick"))
  end

  def test_generate_quick_index
    initialize_server_directory

    generate_yaml_index("--directory #{SERVER_DIR}")

    assert_equal '', @out
    assert_equal '', @err
    assert_equal 0, @status, "no status error"
    assert File.exist?(srvfile("yaml"))
    assert File.exist?(srvfile("yaml.Z"))
    assert File.exist?(srvfile("quick"))
    assert File.exist?(srvfile("quick/index"))
    assert File.exist?(srvfile("quick/index.rz"))
    assert File.exist?(srvfile("quick/one-0.0.1.gemspec.rz"))
    assert ! File.exist?(srvfile("quick/one-0.0.1.gemspec"))
  end

  def initialize_server_directory
    FileUtils.rm_r srvfile("quick") rescue nil
    FileUtils.rm_r srvfile("yaml") rescue nil
    FileUtils.rm_r srvfile("yaml.Z") rescue nil
    unless File.exist?(srvfile("gems"))
      FileUtils.mkdir_p(srvfile("gems"))
    end
    OneGem.make(self)
    FileUtils.cp OneGem::ONEGEM, srvfile("gems")
  end

  # Run the generate_yaml_index command for the functional test.
  def generate_yaml_index(options="")
    shell = Session::Shell.new
    command = "#{Gem.ruby} #{@ruby_options} #{@gyi_path} #{options}"
    puts "\n\nCOMMAND: [#{command}]" if @verbose
    @out, @err = shell.execute command
    @status = shell.exit_status
    puts "STATUS:  [#{@status}]" if @verbose
    puts "OUTPUT:  [#{@out}]" if @verbose
    puts "ERROR:   [#{@err}]" if @verbose
    puts "PWD:     [#{Dir.pwd}]" if @verbose
    shell.close
  end

  # Run a gem command for the functional test.
  def gem(options="")
    cmd = "#{Gem.ruby} #{@ruby_options} #{@gem_path} #{options}"
    system cmd
  end

  def srvfile(name)
    File.join(SERVER_DIR, name)
  end
end

