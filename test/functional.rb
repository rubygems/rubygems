#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'rubygems'
Gem.manage_gems
require 'yaml'
require 'fileutils'
require 'test/insure_session'
require 'test/onegem'

class FunctionalTest < Test::Unit::TestCase
  def setup
    @gem_path = File.expand_path("bin/gem")
    lib_path = File.expand_path("lib")
    @ruby_options = "-I#{lib_path} -I."
    @verbose = false
  end

  def test_gem_help_options
    gem_nossl 'help options'
    assert_match(/Usage:/, @out)
    assert_status
  end

  def test_gem_help_commands
    gem_nossl 'help commands'
    assert_match(/gem install/, @out)
    assert_status
  end

  def test_gem_no_args_shows_help
    gem_nossl
    assert_match(/Usage:/, @out)
    assert_status 1
  end

  def test_environment
    gem_nossl 'environment'
    
    assert_match(/VERSION:\s+(\d+\.)*\d+/, @out)
    assert_match(/INSTALLATION DIRECTORY:/, @out)
    assert_match(/GEM PATH:/, @out)
    assert_match(/REMOTE SOURCES:/, @out)
    assert_status
  end

  def test_env_version
    gem_nossl 'environment version'
    assert_match(/\d+\.\d+$/, @out)
  end

  def test_env_gemdir
    gem_nossl 'environment gemdir'
    assert_equal Gem.dir, @out.chomp
  end

  def test_env_gempath
    gem_nossl 'environment gempath'
    assert_equal Gem.path, @out.chomp.split("\n")
  end

  def test_env_remotesources
    gem_nossl 'environment remotesources'
    assert_equal Gem.sources, @out.chomp.split("\n")
  end

  def test_build
    OneGem.rebuild(self)
    assert File.exist?(OneGem::ONEGEM), "Gem file (#{OneGem::ONEGEM}) should exist"
    assert_match(/Successfully built RubyGem/, @out)
    assert_match(/Name: one$/, @out)
    assert_match(/Version: 0.0.1$/, @out)
    assert_match(/File: #{OneGem::ONENAME}/, @out)
    spec = read_gem_file(OneGem::ONEGEM)
    assert_equal "one", spec.name
    assert_equal "Test GEM One", spec.summary
  end

  def test_build_from_yaml
    OneGem.rebuild(self)
    assert File.exist?(OneGem::ONEGEM), "Gem file (#{OneGem::ONEGEM}) should exist"
    assert_match(/Successfully built RubyGem/, @out)
    assert_match(/Name: one$/, @out)
    assert_match(/Version: 0.0.1$/, @out)
    assert_match(/File: #{OneGem::ONENAME}/, @out)
    spec = read_gem_file(OneGem::ONEGEM)
    assert_equal "one", spec.name
    assert_equal "Test GEM One", spec.summary
  end

  # This test is disabled because of the insanely long time it takes
  # to time out.
  def xtest_bogus_source_hoses_up_remote_install_but_gem_command_gives_decent_error_message
    @ruby_options << " -rtest/bogussources"
    gem_nossl "install asdf --remote"
    assert_match(/error/im, @err)
    assert_status 1
  end

  def test_all_command_helps
    mgr = Gem::CommandManager.new
    mgr.command_names.each do |cmdname|
      gem_nossl "help #{cmdname}"
      assert_match(/Usage: gem #{cmdname}/, @out,
                   "should see help for #{cmdname}")
    end
  end

  def test_gemrc_paths
    gem_nossl "env --config-file test/testgem.rc"
    assert_match %{/usr/local/rubygems}, @out
    assert_match %{/another/spot/for/rubygems}, @out
    assert_match %{test/data/gemhome}, @out
  end

  def test_gemrc_args
    gem_nossl "help --config-file test/testgem.rc"
    assert_match %{gem build}, @out
    assert_match %{gem install}, @out
  end

  SIGN_FILES = %w(gem-private_key.pem gem-public_cert.pem)

  def test_cert_build
    begin
      require 'openssl'
    rescue LoadError => ex
      puts "WARNING: openssl is not availble, " +
        "unable to test the cert functions"
      return
    end

    SIGN_FILES.each do |fn| FileUtils.rm_f fn end
    gem_withssl "cert --build x@y.z"
    SIGN_FILES.each do |fn| 
      assert File.exist?(fn),
        "Signing key/cert file '#{fn}' should exist"
    end
  ensure
    SIGN_FILES.each do |fn| FileUtils.rm_f fn end
  end

  def test_nossl_cert
    gem_nossl "cert --build x@y.z"
    assert_not_equal 0, @status
    assert_match(/not installed/, @err, 
                 "Should have a not installed error for openssl")
  end

  # :section: Help Methods

  # Run a gem command without the SSL library.
  def gem_nossl(options="")
    old_options = @ruby_options.dup
    @ruby_options << " -Itest/fake_certlib"
    gem(options)
  ensure
    @ruby_options = old_options
  end

  # Run a gem command with the SSL library.
  def gem_withssl(options="")
    gem(options)
  end

  # Run a gem command for the functional test.
  def gem(options="")
    shell = Session::Shell.new
    options = options + " --config-file missing_file" if options !~ /--config-file/
    command = "#{Gem.ruby} #{@ruby_options} #{@gem_path} #{options}"
    puts "\n\nCOMMAND: [#{command}]" if @verbose
    @out, @err = shell.execute command
    @status = shell.exit_status
    puts "STATUS:  [#{@status}]" if @verbose
    puts "OUTPUT:  [#{@out}]" if @verbose
    puts "ERROR:   [#{@err}]" if @verbose
    puts "PWD:     [#{Dir.pwd}]" if @verbose
    shell.close
  end

  private

  def assert_status(expected_status=0)
    assert_equal expected_status, @status
  end

  def read_gem_file(filename)
    Gem::Format.from_file_by_path(filename).spec
  end

end
