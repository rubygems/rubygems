#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/gemutilities'
require 'rubygems/remote_installer'
require 'test/unit'

class TestLocalCache < RubyGemTestCase

  def setup
    super
    @lc = Gem::SourceInfoCache.new
    prep_cache_files(@lc)
  end

  def test_file_names
    assert_equal File.join(Gem.dir, "source_cache"), @lc.system_cache_file
    assert_equal @usrcache, @lc.user_cache_file
  end

  def test_gem_cache_env_variable
    assert_equal @usrcache, @lc.user_cache_file
  end

  def test_use_system_by_default
    assert_equal "sys", @lc.cache_data['key']
  end

  def test_use_user_cache_when_sys_no_writable
    FileUtils.chmod 0544, @lc.system_cache_file

    @lc = Gem::SourceInfoCache.new
    assert_equal "usr", @lc.cache_data['key']
  end

  def test_write_system_cache
    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'new']].sort, read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'usr']].sort, read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_flush
    @lc.cache_data['key'] = 'new'
    @lc.update
    @lc.flush

    assert_equal [['key','new']].sort, read_cache(@lc.system_cache_file).to_a.sort
  end

  def test_write_user_cache
    FileUtils.chmod 0544, @lc.system_cache_file
    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'sys']].sort, read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'new']].sort, read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_write_user_cache_from_scratch
    FileUtils.rm_rf @lc.user_cache_file
    FileUtils.chmod 0544, @lc.system_cache_file

    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'sys']].sort, read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'new']].sort, read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_write_user_directory_and_cache_from_scratch
    FileUtils.rm_rf File.dirname(@lc.user_cache_file)
    FileUtils.chmod 0544, @lc.system_cache_file

    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key','sys']].sort, read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key','new']].sort, read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_read_system_cache
    assert_equal [['key','sys']].sort, @lc.cache_data.to_a.sort
  end

  def test_read_user_cache
    FileUtils.chmod 0544, @lc.system_cache_file

    assert_equal [['key','usr']].sort, @lc.cache_data.to_a.sort
  end

  def test_no_writable_cache
    FileUtils.chmod 0544, @lc.system_cache_file
    FileUtils.chmod 0544, @lc.user_cache_file
    assert_raise(RuntimeError) {
      @lc.cache_data
    }
  end
end

