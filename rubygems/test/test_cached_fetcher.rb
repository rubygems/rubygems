#!/usr/bin/env ruby

require 'test/unit'
require 'fileutils'

require 'rubygems/remote_installer'
require 'test/yaml_data'
require 'test/gemutilities'

class TestCachedFetcher < Test::Unit::TestCase
  SOURCE_URI = "http://localhost:12344"
  GEMHOME = "test/temp/writable_cache"

  class MockFetcher
    attr_reader :count
    attr_accessor :size

    def initialize
      @count = 0
      @size = 5
    end

    def fetch_path(path=nil)
    end
    
    def source_index
      @count += 1
    end
  end

  def setup
    make_cache_area(GEMHOME, "http://localhost:12344")
    Gem.clear_paths
    Gem.use_paths(GEMHOME)
    @cf = Gem::CachedFetcher.new(SOURCE_URI, nil)
    @mf = MockFetcher.new
    @cf.instance_variable_set("@fetcher", @mf)
  end

  def test_create
    assert_not_nil @cf
    assert_equal 5, @cf.size
    assert_equal 0, @mf.count
  end

  def test_cache_miss
    @cf.source_index
    assert_equal 1, @mf.count
  end

  def test_cache_hit
    @mf.size = YAML_DATA.size
    @cf.source_index
    assert_equal 0, @mf.count
  end

  def make_cache_area(path, *uris)
    Utilities.make_cache_area(path, *uris)
  end
end
