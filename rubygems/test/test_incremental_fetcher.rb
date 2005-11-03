#!/usr/bin/env ruby

require 'test/unit'
require 'fileutils'

require 'rubygems/incremental_fetcher'
require 'rubygems/remote_installer'
require 'test/yaml_data'
require 'test/gemutilities'

class TestIncrementalFetcher < RubyGemTestCase

  class MockFetcher
    attr_reader :count
    attr_accessor :size
    attr_accessor :quick_enabled

    def initialize
      @count = 0
      @size = 5
      @quick_enabled = true
    end

    def fetch_path(path=nil)
      case path
      when 'quick/index.gz'
	unless @quick_enabled
	  fail Exception, "Quick index not found [#{path}]"
	end
	"x"
      else
	fail "File not found [#{path}]"
      end
    end
    
    def source_index
      @count += 1
    end
  end

  class UniversalLookup
    def initialize(data)
      @data = data
    end
    def [](index)
      @data
    end
  end

  class MockCacheManager
    def initialize(x)
      @x = x
    end
    def cache_data
      si = Gem::SourceIndex.new( {
	  'a-1.0' => @x.quick_gem('a', '1.0')
	} )
      UniversalLookup.new( SourceInfoCacheEntry.new(si, si.to_yaml.size) )
    end
  end

  def setup
    super
    @source_uri = "http://localhost:12344"
    make_cache_area(@gemhome, @source_uri)
    @mf = MockFetcher.new
    @cm = Gem::SourceInfoCache.new
    @inc = Gem::IncrementalFetcher.new(@source_uri, @mf, @cm)
  end

  def test_cache_is_properly_setup
    assert @cm.cache_data[@source_uri].size > 800,
      "Cache size should be over 800 (at least)"
    srcindex = @cm.cache_data[@source_uri].source_index
    assert_equal Gem::SourceIndex, srcindex.class
    assert_equal 1, srcindex.size
    specs = srcindex.find_name('rake')
    assert_equal "rake", specs.first.name
  end

  def test_no_quick_index_on_source
    @mf.quick_enabled = false
    assert_raise(Gem::OperationNotSupportedError) {
      @inc.source_index
    }
  end

  def test_matching_hashes
    @inc.source_index
  end

  def make_cache_area(path, *uris)
    Utilities.make_cache_area(path, *uris)
  end
end
