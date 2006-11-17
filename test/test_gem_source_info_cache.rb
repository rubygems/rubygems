#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/gemutilities'
require 'rubygems/remote_installer'
require 'test/unit'

class TestGemSourceInfoCache < RubyGemTestCase

  def setup
    super
    @lc = Gem::SourceInfoCache.new
    prep_cache_files(@lc)
  end

  def test_cache_data
    assert_equal [['key','sys']], @lc.cache_data.to_a.sort
  end

  def test_cache_data_dirty
    def @lc.dirty() @dirty; end
    assert_equal false, @lc.dirty, 'clean on init'
    @lc.cache_data
    assert_equal false, @lc.dirty, 'clean on fetch'
    @lc.update
    @lc.cache_data
    assert_equal true, @lc.dirty, 'still dirty'
  end

  def test_cache_data_none_readable
    FileUtils.chmod 0222, @lc.system_cache_file
    FileUtils.chmod 0222, @lc.user_cache_file
    assert_equal({}, @lc.cache_data)
  end

  def test_cache_data_none_writable
    FileUtils.chmod 0444, @lc.system_cache_file
    FileUtils.chmod 0444, @lc.user_cache_file
    e = assert_raise RuntimeError do
      @lc.cache_data
    end
    assert_equal 'unable to locate a writable cache file', e.message
  end

  def test_cache_data_user_fallback
    FileUtils.chmod 0444, @lc.system_cache_file
    assert_equal [['key','usr']], @lc.cache_data.to_a.sort
  end

  def test_cache_file
    assert_equal @gemcache, @lc.cache_file
  end

  def test_cache_file_user_fallback
    FileUtils.chmod 0444, @lc.system_cache_file
    assert_equal @usrcache, @lc.cache_file
  end

  def test_cache_file_none_writable
    FileUtils.chmod 0444, @lc.system_cache_file
    FileUtils.chmod 0444, @lc.user_cache_file
    e = assert_raise RuntimeError do
      @lc.cache_file
    end
    assert_equal 'unable to locate a writable cache file', e.message
  end

  def test_flush
    @lc.cache_data['key'] = 'new'
    @lc.update
    @lc.flush

    assert_equal [['key','new']], read_cache(@lc.system_cache_file).to_a.sort
  end

  def test_read_system_cache
    assert_equal [['key','sys']], @lc.cache_data.to_a.sort
  end

  def test_read_user_cache
    FileUtils.chmod 0444, @lc.system_cache_file

    assert_equal [['key','usr']], @lc.cache_data.to_a.sort
  end

  def test_system_cache_file
    assert_equal File.join(Gem.dir, "source_cache"), @lc.system_cache_file
  end

  def test_user_cache_file
    assert_equal @usrcache, @lc.user_cache_file
  end

  def test_write_cache
    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'new']],
                 read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'usr']],
                 read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_write_cache_user
    FileUtils.chmod 0444, @lc.system_cache_file
    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'sys']], read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'new']], read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_write_cache_user_from_scratch
    FileUtils.rm_rf @lc.user_cache_file
    FileUtils.chmod 0444, @lc.system_cache_file

    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key', 'sys']], read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key', 'new']], read_cache(@lc.user_cache_file).to_a.sort
  end

  def test_write_cache_user_no_directory
    FileUtils.rm_rf File.dirname(@lc.user_cache_file)
    FileUtils.chmod 0444, @lc.system_cache_file

    @lc.cache_data['key'] = 'new'
    @lc.write_cache

    assert_equal [['key','sys']], read_cache(@lc.system_cache_file).to_a.sort
    assert_equal [['key','new']], read_cache(@lc.user_cache_file).to_a.sort
  end

end

