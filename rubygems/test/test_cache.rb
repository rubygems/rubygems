require 'test/unit'
require 'rubygems'
Gem::manage_gems

class TestCache < Test::Unit::TestCase

  def test_search_for_missing_gem_returns_nothing
    gems = Gem::Cache.new(@sample_cache).search("bogusstring")
    assert_equal(gems.size, 0)
  end

  def test_search_empty_cache_returns_nothing
    gems = Gem::Cache.new({}).search("foo")
    assert_equal(gems.size, 0)
  end

  def test_search_with_full_gem_name_returns_gem
    gems = Gem::Cache.new(@sample_cache).search("foo")
    assert_equal(gems.size, 1)
  end

  def test_search_with_full_gem_name_and_version_returns_gem
    gems = Gem::Cache.new(@sample_cache).search("foo", "= 1.2.3")
    assert_equal(gems.size, 1)
  end

  def test_search_with_full_gem_name_and_wrong_version_returns_nothing
    gems = Gem::Cache.new(@sample_cache).search("foo", "= 3.2.1")
    assert_equal(gems.size, 0)
  end

  def test_search_with_full_gem_name_in_mixed_case_returns_gem
    gems = Gem::Cache.new(@sample_cache).search("FOo")
    assert_equal(gems.size, 1, "This is failing because we have duplication between remote_installer and cache.rb.  We should factor remote_installer's search logic out into cache.rb's search and delegate from remote_installer to cache.rb")
  end

  def setup
    @sample_spec = Gem::Specification.new do |s|
      s.name = 'foo'
      s.version = "1.2.3"
      s.platform = Gem::Platform::RUBY
      s.summary = "This is a cool package"
      s.files = [] 
    end 
    @second_sample_spec = Gem::Specification.new do |s|
      s.name = 'anothergem'
      s.version = "0.0.1"
      s.platform = Gem::Platform::RUBY
      s.summary = "This is a cool package"
      s.files = [] 
    end 
    @sample_cache = { 'foo-1.2.3' => @sample_spec }
  end
end
