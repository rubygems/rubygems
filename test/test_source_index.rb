#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/source_index'

Gem.manage_gems

class Gem::SourceIndex
  public :convert_specs, :fetcher, :fetch_bulk_index, :fetch_quick_index,
         :find_missing, :gems, :reduce_specs, :remove_extra,
         :update_with_missing, :unzip
end

class TestSourceIndex < RubyGemTestCase

  def setup
    super

    util_setup_fake_fetcher
  end

  def test_convert_specs
    specs = @source_index.convert_specs([@gem1].to_yaml)

    @gem1.files = []

    assert_equal [@gem1], specs
  end

  def test_create_from_directory
    # TODO
  end

  def test_fetcher
    assert_equal @fetcher, @source_index.fetcher
  end

  def test_fetch_bulk_index_compressed
    util_setup_bulk_fetch true
    use_ui MockGemUi.new do
      fetched_index = @source_index.fetch_bulk_index @uri
      assert_equal [@gem1.full_name, @gem4.full_name, @gem2.full_name].sort,
                   fetched_index.gems.map { |n,s| n }.sort
    end
  end

  def test_fetch_bulk_index_error
    @fetcher.data["http://gems.example.com/yaml.Z"] = proc { raise SocketError }
    @fetcher.data["http://gems.example.com/yaml"] = proc { raise SocketError }

    e = assert_raise Gem::RemoteSourceException do
      use_ui MockGemUi.new do
        @source_index.fetch_bulk_index @uri
      end
    end

    assert_equal 'Error fetching remote gem cache: SocketError',
                 e.message
  end

  def test_fetch_bulk_index_uncompressed
    util_setup_bulk_fetch false
    use_ui MockGemUi.new do
      fetched_index = @source_index.fetch_bulk_index @uri
      assert_equal [@gem1.full_name, @gem4.full_name, @gem2.full_name].sort,
                   fetched_index.gems.map { |n,s| n }.sort
    end
  end

  def test_fetch_quick_index
    quick_index = util_zip @gem_names
    @fetcher.data['http://gems.example.com/quick/index.rz'] = quick_index

    quick_index = @source_index.fetch_quick_index @uri
    assert_equal [@gem1.full_name, @gem4.full_name, @gem2.full_name].sort,
                 quick_index.sort
  end

  def test_fetch_quick_index_error
    @fetcher.data['http://gems.example.com/quick/index.rz'] =
      proc { raise Exception }

    e = assert_raise Gem::OperationNotSupportedError do
      @source_index.fetch_quick_index @uri
    end

    assert_equal 'No quick index found: Exception', e.message
  end

  def test_find_missing
    missing = @source_index.find_missing [@gem3.full_name]
    assert_equal [@gem3.full_name], missing
  end

  def test_find_missing_none_missing
    missing = @source_index.find_missing @gem_names.split
    assert_equal [], missing
  end

  def test_latest_specs
    spec = quick_gem @gem1.name, '0.0.1'
    @source_index.add_spec spec

    expected = {
      @gem1.name => @gem1,
      @gem2.name => @gem2,
      @gem4.name => @gem4
    }

    assert_equal expected, @source_index.latest_specs
  end

  def test_outdated
    sic = Gem::SourceInfoCache.new
    Gem::SourceInfoCache.instance_variable_set :@cache, sic

    assert_equal [], @source_index.outdated

    updated = quick_gem @gem1.name, '999'
    util_setup_source_info_cache updated

    assert_equal [updated.name], @source_index.outdated
  ensure
    Gem::SourceInfoCache.instance_variable_set :@cache, nil
  end

  def test_reduce_specs
    specs = YAML.load @source_index.reduce_specs([@gem1].to_yaml)
    assert_equal [], specs.first.files
  end

  def test_remove_extra
    @source_index.remove_extra [@gem1.full_name]
    assert_equal [@gem1.full_name], @source_index.gems.map { |n,s| n }
  end

  def test_remove_extra_no_changes
    gems = @gem_names.split.sort
    @source_index.remove_extra gems
    assert_equal gems, @source_index.gems.map { |n,s| n }.sort
  end

  def test_search
    assert_equal [@gem1, @gem4], @source_index.search("gem_one")
    assert_equal [@gem1], @source_index.search("gem_one", "= 0.0.2")

    assert_equal [], @source_index.search("bogusstring")
    assert_equal [], @source_index.search("gem_one", "= 3.2.1")
  end

  def test_search_empty_cache
    empty_source_index = Gem::SourceIndex.new({})
    assert_equal [], empty_source_index.search("foo")
  end

  def test_signature
    sig = @source_index.gem_signature('foo-1.2.3')
    assert_equal 64, sig.length
    assert_match(/^[a-f0-9]{64}$/, sig)
  end

  def test_specification
    assert_equal @gem1, @source_index.specification(@gem1.full_name)

    assert_nil @source_index.specification("foo-1.2.4")
  end

  def test_index_signature
    sig = @source_index.index_signature
    assert_match(/^[a-f0-9]{64}$/, sig)
  end

  def test_unzip
    input = "x\234+\316\317MU(I\255(\001\000\021\350\003\232"
    assert_equal 'some text', @source_index.unzip(input)
  end

  def test_update_bulk
    util_setup_bulk_fetch true

    @source_index.gems.replace({})
    assert_equal [], @source_index.gems.keys.sort

    use_ui MockGemUi.new do
      @source_index.update @uri

      assert_equal @gem_names.split, @source_index.gems.keys.sort
    end
  end

  def test_update_incremental
    quick_index = util_zip @gem_names
    @fetcher.data['http://gems.example.com/quick/index.rz'] = quick_index

    spec_uri = "http://gems.example.com/quick/#{@gem3.full_name}.gemspec.rz"
    @fetcher.data[spec_uri] = util_zip @gem3.to_yaml

    use_ui MockGemUi.new do
      @source_index.update @uri

      assert_equal @gem_names.split, @source_index.gems.keys.sort
    end
  end

  def test_update_with_missing
    spec_uri = "http://gems.example.com/quick/#{@gem3.full_name}.gemspec.rz"
    @fetcher.data[spec_uri] = util_zip @gem3.to_yaml

    use_ui MockGemUi.new do
      @source_index.update_with_missing @uri, [@gem3.full_name]
    end

    assert_equal @gem3, @source_index.specification(@gem3.full_name)
  end

  def util_setup_bulk_fetch(compressed)
    source_index = @source_index.to_yaml

    if compressed then
      @fetcher.data['http://gems.example.com/yaml.Z'] = util_zip source_index
    else
      @fetcher.data['http://gems.example.com/yaml'] = source_index
    end
  end

end
