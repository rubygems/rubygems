#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'fileutils'
require 'flexmock'

require 'rubygems/incremental_fetcher'
require 'rubygems/remote_installer'
require 'test/yaml_data'
require 'test/gemutilities'

class TestIncrementalFetcher < RubyGemTestCase
  include Gem::DefaultUserInteraction

  TEST_URI = "http://onestepback.org/betagems"

  def setup
    super
    @fetcher = FlexMock.new("RemoteFetcher")
    @manager = FlexMock.new("SourceInfoCache")
    @inc = Gem::IncrementalFetcher.new(TEST_URI, @fetcher, @manager)
    @existing_index = Gem::SourceIndex.new
    @existing_index.add_spec(quick_gem("a", "1.0"))
    @existing_index.add_spec(quick_gem("b", "2.0"))
    @sice = Gem::SourceInfoCacheEntry.new(@existing_index, 100)

    @url_hash = { TEST_URI => @sice}
    @manager.should_receive(:cache_data).and_return(@url_hash)

    @old_ui = ui
    self.ui = Gem::SilentUI.new
  end

  def teardown
    self.ui = @old_ui
  end

  def verify
    [ @fetcher, @manager ].each do |it| it.mock_verify end
  end

  def zipped(string)
    require 'zlib'
    Zlib::Deflate.deflate(string)
  end

  def new_source_index
    result = Gem::SourceIndex.new
    result.add_spec(quick_gem("a", "1.0"))
    result.add_spec(quick_gem("b", "2.0"))
    result.add_spec(quick_gem("b", "2.1"))
    result
  end

  def test_creation
    assert_not_nil @inc
    verify
  end

  def test_remote_size_matches_cached_data_returns_cache
    @fetcher.should_receive(:size).with_no_args.and_return(100).once
    @manager.should_receive(:update).never

    si = @inc.source_index

    assert si.specification("a-1.0")
    assert si.specification("b-2.0")
    assert_equal 2, si.search(/./).size
    verify
  end

  def test_remote_size_differs_and_remote_has_additional_specs
    @fetcher.should_receive(:size).with_no_args.and_return(200).once
    @fetcher.should_receive(:fetch_path).with("/quick/index.rz").once.
      and_return(zipped("a-1.0\nb-2.0\na-1.1\n"))
    @fetcher.should_receive(:fetch_path).with("/quick/a-1.1.gemspec.rz").once.
      and_return(zipped(quick_gem("a", "1.1").to_yaml))
    @manager.should_receive(:update).at_least.once.ordered
    @manager.should_receive(:flush).at_least.once.ordered

    si = @inc.source_index

    assert si.specification("a-1.0")
    assert si.specification("a-1.1")
    assert si.specification("b-2.0")
    assert_equal 3, si.search(/./).size
    verify
  end

  def test_remote_size_differs_and_remote_has_fewer_specs
    @fetcher.should_receive(:size).with_no_args.and_return(200).once
    @fetcher.should_receive(:fetch_path).with("/quick/index.rz").once.
      and_return(zipped("a-1.0\n"))
    @manager.should_receive(:update).at_least.once.ordered
    @manager.should_receive(:flush).at_least.once.ordered

    si = @inc.source_index

    assert si.specification("a-1.0")
    assert_equal 1, si.search(/./).size
    verify
  end

  def test_remote_size_differs_and_no_quick_index_is_available
    @fetcher.should_receive(:size).with_no_args.and_return(200).once
    @fetcher.should_receive(:fetch_path).with("/quick/index.rz").once.
      and_return { fail RuntimeError, "No quick/index.rz file available" }
    new_si = new_source_index
    @fetcher.should_receive(:source_index).with_no_args.and_return(new_si)

    si = @inc.source_index

    assert_equal new_si.object_id, si.object_id
    assert si.specification("a-1.0")
    assert si.specification("b-2.0")
    assert si.specification("b-2.1")
    assert_equal 3, si.search(/./).size
    verify
  end

  def test_no_source_index_found_for_uri
    @fetcher.should_receive(:size).with_no_args.and_return(200).once
    @fetcher.should_receive(:fetch_path).with("/quick/index.rz").once.
      and_return(zipped("a-1.0\n"))
    @fetcher.should_receive(:fetch_path).with("/quick/a-1.0.gemspec.rz").once.
      and_return(zipped(quick_gem("a", "1.0").to_yaml))
    @manager.should_receive(:update).at_least.once.ordered
    @manager.should_receive(:flush).at_least.once.ordered
    @url_hash.delete(TEST_URI)

    si = @inc.source_index

    assert si.specification('a-1.0')
    assert_equal 1, si.search(/./).size
    verify    
  end

  def test_fetch_where_some_gemspecs_cant_be_retrieved
    @fetcher.should_receive(:size).with_no_args.and_return(200).once
    @fetcher.should_receive(:fetch_path).with("/quick/index.rz").once.
      and_return(zipped("a-1.0\nb-2.0\na-1.1\na-1.2\na-1.3\n"))
    @fetcher.should_receive(:fetch_path).with("/quick/a-1.1.gemspec.rz").once.
      and_return(zipped(quick_gem("a", "1.1").to_yaml))
    @fetcher.should_receive(:fetch_path).with("/quick/a-1.2.gemspec.rz").once.
      and_return { fail "No gem found for a-1.2" }
    @fetcher.should_receive(:fetch_path).with("/quick/a-1.3.gemspec.rz").once.
      and_return(zipped(quick_gem("a", "1.3").to_yaml))
    @manager.should_receive(:update).at_least.once.ordered
    @manager.should_receive(:flush).at_least.once.ordered

    si = @inc.source_index

    assert si.specification("a-1.0")
    assert si.specification("a-1.1")
    assert si.specification("a-1.3")
    assert si.specification("b-2.0")
    assert_nil si.specification("a-1.2")
    assert_equal 4, si.search(/./).size
    verify
  end

  def test_basic_fetching
    @fetcher.should_receive(:fetch_path).with("xyz").once.
      and_return("abc")

    assert_equal "abc", @inc.fetch_path("xyz")
  end

end
