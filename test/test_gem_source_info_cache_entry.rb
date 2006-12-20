require 'test/unit'
require 'test/gemutilities'

class TestGemSourceInfoCacheEntry < RubyGemTestCase

  def setup
    super

    util_setup_fake_fetcher

    @si = Gem::SourceIndex.new @gem1.full_name => @gem1.name
    @sic_e = Gem::SourceInfoCacheEntry.new @si, @si.to_yaml.length
  end

  def test_refresh
    @fetcher.data['http://gems.example.com/yaml.Z'] = proc { raise Exception }
    @fetcher.data['http://gems.example.com/yaml'] = @si.to_yaml

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
    @fetcher.data['http://gems.example.com/yaml'] = si.to_yaml

    use_ui MockGemUi.new do
      @sic_e.refresh 'http://gems.example.com'
    end

    new_gem = @sic_e.source_index.specification(@gem2.full_name)
    assert_equal @gem2.full_name, new_gem.full_name
  end

end

