require 'test/unit'
require 'test/gemutilities'
require 'rubygems/source_info_cache_entry'

class TestGemSourceInfoCacheEntry < RubyGemTestCase

  def setup
    super

    util_setup_fake_fetcher

    @si = Gem::SourceIndex.new @gem1.full_name => @gem1.name
    @sic_e = Gem::SourceInfoCacheEntry.new @si, @si.dump.size
  end

  def test_refresh
    @fetcher.data['http://gems.example.com/Marshal.Z'] = proc { raise Exception }
    @fetcher.data['http://gems.example.com/Marshal'] = @si.dump

    assert_nothing_raised do
      @sic_e.refresh 'http://gems.example.com'
    end
  end

  def test_refresh_bad_uri
    assert_raise ArgumentError do
      @sic_e.refresh 'gems.example.com'
    end
  end

  def test_refresh_update
    si = Gem::SourceIndex.new @gem1.full_name => @gem1,
                              @gem2.full_name => @gem2
    @fetcher.data['http://gems.example.com/Marshal'] = si.dump

    use_ui @ui do
      @sic_e.refresh 'http://gems.example.com'
    end

    new_gem = @sic_e.source_index.specification(@gem2.full_name)
    assert_equal @gem2.full_name, new_gem.full_name
  end

end

