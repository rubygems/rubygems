#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'fileutils'
require 'rubygems'
require 'test/gemutilities'

class TestGemPaths < RubyGemTestCase
  def setup
    super
    Gem.clear_paths
    ENV['GEM_HOME'] = nil
    ENV['GEM_PATH'] = nil
    @additional = ['a', 'b'].map { |f| File.join(@tempdir, f) }
  end

  def teardown
    super
    ENV['GEM_HOME'] = nil
    ENV['GEM_PATH'] = nil
  end

  DEFAULT_DIR_RE = %r{/ruby/gems/[0-9.]+}

  def test_default_dir
    assert_match DEFAULT_DIR_RE, Gem.dir
  end

  def test_default_dir_subdirectories
    Gem::DIRECTORIES.each do |filename|
      assert File.exists?(File.join(Gem.dir, filename)), "expected #{filename} to exist"
    end
  end

  def test_gem_home
    ENV['GEM_HOME'] = @gemhome
    assert_equal @gemhome, Gem.dir
  end

  def test_gem_home_subdirectories
    ENV['GEM_HOME'] = @gemhome
    ['cache', 'doc', 'gems', 'specifications'].each do |filename|
      assert File.exists?(File.join(@gemhome, filename)), "expected #{filename} to exist"
    end
  end

  def test_default_path
    assert_equal [Gem.dir], Gem.path
  end

  def test_additional_paths
    create_additional_gem_dirs
    ENV['GEM_PATH'] = @additional.join(File::PATH_SEPARATOR)
    assert_equal @additional, Gem.path[0,2]
    assert_equal 3, Gem.path.size
    assert_match DEFAULT_DIR_RE, Gem.path.last
  end

  def test_dir_path_overlap
    create_additional_gem_dirs
    ENV['GEM_HOME'] = @gemhome
    ENV['GEM_PATH'] = @additional.join(File::PATH_SEPARATOR)
    assert_equal @gemhome, Gem.dir
    assert_equal @additional + [Gem.dir], Gem.path
  end

  def test_dir_path_overlaping_duplicates_removed
    create_additional_gem_dirs
    dirs = [@gemhome] + @additional + [File.join(@tempdir, 'a')]
    ENV['GEM_HOME'] = @gemhome
    ENV['GEM_PATH'] = dirs.join(File::PATH_SEPARATOR)
    assert_equal @gemhome, Gem.dir
    assert_equal [Gem.dir] + @additional, Gem.path
  end

  def test_path_use_home
    create_additional_gem_dirs
    Gem.use_paths(@gemhome)
    assert_equal @gemhome, Gem.dir
    assert_equal [Gem.dir], Gem.path
  end

  def test_path_use_home_and_dirs
    create_additional_gem_dirs
    Gem.use_paths(@gemhome, @additional)
    assert_equal @gemhome, Gem.dir
    assert_equal @additional+[Gem.dir], Gem.path
  end

  def test_user_home
    if ENV['HOME']
      assert_equal ENV['HOME'], Gem.user_home
    end
  end

  def test_ensure_gem_directories_new
    FileUtils.rm_r(@gemhome)
    Gem.use_paths(@gemhome)
    Gem.send(:ensure_gem_subdirectories, @gemhome)
    assert File.exist?(File.join(@gemhome, "cache"))
  end

  def test_ensure_gem_directories_missing_parents
    gemdir = File.join(@tempdir, "a/b/c/gemdir")
    FileUtils.rm_r(File.join(@tempdir, "a")) rescue nil
    Gem.use_paths(gemdir)
    Gem.send(:ensure_gem_subdirectories, gemdir)
    assert File.exist?("#{gemdir}/cache")
  end

  def test_ensure_gem_directories_write_protected
    return if win_platform? #This test works only for FS that support write protection
    
    gemdir = File.join(@tempdir, "egd")
    FileUtils.rm_r gemdir rescue nil
    FileUtils.mkdir_p gemdir
    FileUtils.chmod 0400, gemdir
    Gem.use_paths(gemdir)
    Gem.send(:ensure_gem_subdirectories, gemdir)
    assert ! File.exist?("#{gemdir}/cache")
  ensure
    FileUtils.chmod(0600, gemdir) rescue nil
    FileUtils.rm_r gemdir rescue nil
  end

  def test_ensure_gem_directories_with_parents_write_protected
    return if win_platform? #This test works only for FS that support write protection

    parent = File.join(@tempdir, "egd")
    gemdir = "#{parent}/a/b/c"
    
    FileUtils.rm_r parent rescue nil
    FileUtils.mkdir_p parent
    FileUtils.chmod 0400, parent
    Gem.use_paths(gemdir)
    Gem.send(:ensure_gem_subdirectories, gemdir)
    assert !File.exist?("#{gemdir}/cache")
  ensure
    FileUtils.chmod(0600, parent) rescue nil
    FileUtils.rm_r parent rescue nil
  end

  private

  def create_additional_gem_dirs
    create_gem_dir(@gemhome)
    @additional.each do |dir| create_gem_dir(dir) end
  end

  def create_gem_dir(fn)
    Gem::DIRECTORIES.each do |subdir|
      FileUtils.mkdir_p(File.join(fn, subdir))
    end
  end

  def redirect_stderr(io)
    old_err = $stderr
    $stderr = io
    yield
  ensure
    $stderr = old_err
  end
end

