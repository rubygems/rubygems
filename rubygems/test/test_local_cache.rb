#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems/remote_installer'
require 'test/gemutilities'

class TestLocalCache < Test::Unit::TestCase
  GEMHOME = "test/temp/gemhome"
  GEMCACHE = File.join(GEMHOME, "source_cache")
  USRCACHE = "test/temp/.gem/user_cache"

  def setup
    ENV['GEMCACHE'] = USRCACHE
    Gem.use_paths("test/temp/gemhome")
  end

  def teardown
    FileUtils.chmod(0644, GEMCACHE) if File.exist? GEMCACHE
    ENV['GEMCACHE'] = nil
    Gem.clear_paths
  end

  def test_create
    lc = Gem::LocalSourceInfoCache.new
    assert_not_nil lc
  end

  def test_file_names
    lc = Gem::LocalSourceInfoCache.new
    assert_equal File.join(Gem.dir, "source_cache"), lc.system_cache_file
    assert_equal USRCACHE, lc.user_cache_file
  end

  def test_gem_cache_env_variable
    lc = Gem::LocalSourceInfoCache.new
    assert_equal USRCACHE, lc.user_cache_file
  end

  def test_write_system_cache
    lc = Gem::LocalSourceInfoCache.new
    prep_cache_files(lc)
    lc.write_cache(['new'])

    assert_equal ['new'], read_cache(lc.system_cache_file)
    assert_equal ['usr'], read_cache(lc.user_cache_file)
  end

  def test_write_user_cache
    lc = Gem::LocalSourceInfoCache.new
    prep_cache_files(lc)
    FileUtils.chmod 0544, lc.system_cache_file

    lc.write_cache(['new'])

    assert_equal ['sys'], read_cache(lc.system_cache_file)
    assert_equal ['new'], read_cache(lc.user_cache_file)
  end

  def test_write_user_cache_from_scratch
    lc = Gem::LocalSourceInfoCache.new
    prep_cache_files(lc)
    FileUtils.rm_rf File.dirname(lc.user_cache_file)
    FileUtils.chmod 0544, lc.system_cache_file

    lc.write_cache(['new'])

    assert_equal ['sys'], read_cache(lc.system_cache_file)
    assert_equal ['new'], read_cache(lc.user_cache_file)
  end

  def test_read_system_cache
    lc = Gem::LocalSourceInfoCache.new
    prep_cache_files(lc)
    age_file(lc.system_cache_file, lc.user_cache_file)

    assert_equal ['sys'], lc.cache_data
  end

  def test_read_user_cache
    lc = Gem::LocalSourceInfoCache.new
    prep_cache_files(lc)
    age_file(lc.user_cache_file, lc.system_cache_file)

    assert_equal ['usr'], lc.cache_data
  end

  private

  def prep_cache_files(lc)
    [ [lc.system_cache_file, 'sys'],
      [lc.user_cache_file, 'usr'],
    ].each do |fn, data|
      FileUtils.mkdir_p File.dirname(fn)
      open(fn, "w") { |f| f.puts [data].to_yaml }
    end
  end

  def age_file(file_to_age, ref_file)
    while File.stat(file_to_age).mtime <= File.stat(ref_file).mtime
      sleep 0.2
      FileUtils.touch(file_to_age)
    end
  end

  def read_cache(fn)
    open(fn) { |f| YAML.load(f) }
  end

end

