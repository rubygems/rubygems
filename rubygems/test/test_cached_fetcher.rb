#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'fileutils'

require 'rubygems/remote_installer'
require 'test/yaml_data'
require 'test/gemutilities'

class TestCachedFetcher < RubyGemTestCase

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
    super
    @source_uri = "http://localhost:12344"
    make_cache_area(@gemhome, @source_uri)
    @cf = Gem::CachedFetcher.new(@source_uri, nil)
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
