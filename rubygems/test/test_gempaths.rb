#!/usr/bin/env ruby

require 'test/unit'
require 'fileutils'

class TestGemPaths < Test::Unit::TestCase
  def setup
    Gem.clear_paths
    ENV['GEM_HOME'] = nil
    ENV['RUBY_GEMS'] = nil
  end

  def teardown
    setup
  end

  DEFAULT_DIR_RE = %r{/ruby/gems/[0-9.]+}
  TEST_GEMDIR = 'test/temp/gemdir'

  def test_default_dir
    assert_match DEFAULT_DIR_RE, Gem.dir
  end

  def test_default_dir_subdirectories
    Gem::DIRECTORIES.each do |filename|
      assert File.exists?(File.join(Gem.dir, filename)), "expected #{filename} to exist"
    end
  end

  def test_gem_home
    ENV['GEM_HOME'] = TEST_GEMDIR
    assert_equal TEST_GEMDIR, Gem.dir
  end

  def test_gem_home_subdirectories
    ENV['GEM_HOME'] = TEST_GEMDIR
    ['cache', 'doc', 'gems', 'specifications'].each do |filename|
      assert File.exists?(File.join(TEST_GEMDIR, filename)), "expected #{filename} to exist"
    end
  end

  def test_default_path
    assert_equal [Gem.dir], Gem.path
  end

  ADDITIONAL = ['test/temp/a', 'test/temp/b']

  def test_additional_paths
    create_additional_gem_dirs
    ENV['RUBY_GEMS'] = ADDITIONAL.join(File::PATH_SEPARATOR)
    assert_equal ADDITIONAL, Gem.path[0,2]
    assert_equal 3, Gem.path.size
    assert_match DEFAULT_DIR_RE, Gem.path.last
  end

  def test_incomplete_gemdir_message
    ENV['RUBY_GEMS'] = 'test/temp/x'
    err = StringIO.new
    redirect_stderr(err) do
      assert_equal 2, Gem.path.size
    end
    assert_match %r{warning: *ruby_gems path }i, err.string
  end

  def test_dir_path_overlap
    create_additional_gem_dirs
    ENV['GEM_HOME'] = 'test/temp/gemdir'
    ENV['RUBY_GEMS'] = ADDITIONAL.join(File::PATH_SEPARATOR)
    assert_equal 'test/temp/gemdir', Gem.dir
    assert_equal ADDITIONAL + [Gem.dir], Gem.path
  end

  def test_dir_path_overlaping_duplicates_removed
    create_additional_gem_dirs
    dirs = ['test/temp/gemdir'] + ADDITIONAL + ['test/temp/a']
    ENV['GEM_HOME'] = 'test/temp/gemdir'
    ENV['RUBY_GEMS'] = dirs.join(File::PATH_SEPARATOR)
    assert_equal 'test/temp/gemdir', Gem.dir
    assert_equal [Gem.dir] + ADDITIONAL, Gem.path
  end

  def test_path_use_home
    create_additional_gem_dirs
    Gem.use_paths("test/temp/gemdir")
    assert_equal "test/temp/gemdir", Gem.dir
    assert_equal [Gem.dir], Gem.path
  end

  def test_path_use_home_and_dirs
    create_additional_gem_dirs
    Gem.use_paths("test/temp/gemdir", ADDITIONAL)
    assert_equal "test/temp/gemdir", Gem.dir
    assert_equal ADDITIONAL+[Gem.dir], Gem.path
  end

  private

  def create_additional_gem_dirs
    create_gem_dir('test/temp/gemdir')
    ADDITIONAL.each do |dir| create_gem_dir(dir) end
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

