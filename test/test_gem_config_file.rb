#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/config_file'

class TestGemConfigFile < RubyGemTestCase

  def setup
    super

    @temp_conf = File.join @tempdir, '.gemrc'

    @cfg_args = %W[--config-file #{@temp_conf}]
    util_config_file
  end

  def test_initialize
    assert_equal @temp_conf, @cfg.config_file_name

    assert_equal false, @cfg.backtrace
    assert_equal false, @cfg.benchmark

    File.open @temp_conf, 'w' do |fp|
      fp.puts ":backtrace: true"
      fp.puts ":benchmark: true"
    end

    util_config_file

    assert_equal true, @cfg.backtrace
    assert_equal true, @cfg.benchmark
  end

  def test_handle_arguments
    args = %w[--backtrace --bunch --of --args here]

    @cfg.send :handle_arguments, args

    assert_equal %w[--bunch --of --args here], @cfg.args
  end

  def test_handle_arguments_backtrace
    assert_equal false, @cfg.backtrace

    args = %w[--backtrace]

    @cfg.send :handle_arguments, args

    assert_equal true, @cfg.backtrace
  end

  def test_handle_arguments_benchmark
    assert_equal true, @cfg.backtrace

    args = %w[--benchmark]

    @cfg.send :handle_arguments, args

    assert_equal false, @cfg.backtrace
  end

  def test_handle_arguments_config_file
    args = %w[--config-file test/testgem.rc]

    @cfg.send :handle_arguments, args

    assert_equal 'test/testgem.rc', @cfg.config_file_name
  end

  def test_handle_arguments_config_file_equals
    args = %w[--config-file=test/testgem.rc]

    @cfg.send :handle_arguments, args

    assert_equal 'test/testgem.rc', @cfg.config_file_name
  end

  def test_handle_arguments_debug
    old_dollar_DEBUG = $DEBUG
    assert_equal false, $DEBUG

    args = %w[--debug]

    @cfg.send :handle_arguments, args

    assert_equal true, $DEBUG
  ensure
    $DEBUG = old_dollar_DEBUG
  end

  def test_handle_arguments_benchmark
    assert_equal false, @cfg.benchmark

    args = %w[--benchmark]

    @cfg.send :handle_arguments, args

    assert_equal true, @cfg.benchmark
  end

  def test_handle_arguments_traceback
    assert_equal false, @cfg.backtrace

    args = %w[--traceback]

    @cfg.send :handle_arguments, args

    assert_equal true, @cfg.backtrace
  end

  def test_really_verbose
    assert_equal false, @cfg.really_verbose

    @cfg.verbose = true

    assert_equal false, @cfg.really_verbose

    @cfg.verbose = 1

    assert_equal true, @cfg.really_verbose
  end

  def util_config_file
    @cfg = Gem::ConfigFile.new @cfg_args
  end

end

