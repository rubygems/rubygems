require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/source_info_cache_entry'

class TestGemSourceInfoCacheEntry < RubyGemTestCase

  def setup
    super

    util_setup_fake_fetcher

    @si = Gem::SourceIndex.new
    @si.add_spec @a1
    @sic_e = Gem::SourceInfoCacheEntry.new @si, @si.dump.size
  end

  def test_refresh
    @fetcher.data["#{@gem_repo}/Marshal.#{@marshal_version}.Z"] =
      proc { raise Exception }
    @fetcher.data["#{@gem_repo}/Marshal.#{@marshal_version}"] = @si.dump

    assert_nothing_raised do
      @sic_e.refresh @gem_repo
    end
  end

  def test_refresh_bad_uri
    assert_raise URI::BadURIError do
      @sic_e.refresh 'gems.example.com'
    end
  end

  def test_refresh_update
    si = Gem::SourceIndex.new
    si.add_spec @a1
    si.add_spec @b2
    @fetcher.data["#{@gem_repo}/Marshal.#{@marshal_version}"] = si.dump

    use_ui @ui do
      @sic_e.refresh @gem_repo
    end

    new_gem = @sic_e.source_index.specification(@b2.full_name)
    assert_equal @b2.full_name, new_gem.full_name
  end

end

