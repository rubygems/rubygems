require 'test/unit'
require 'rubygems'
Gem::manage_gems

class TestSourceIndex < Test::Unit::TestCase

  SAMPLE_SPEC = Gem::Specification.new do |s|
    s.name = 'foo'
    s.version = "1.2.3"
    s.platform = Gem::Platform::RUBY
    s.summary = "This is a cool package"
    s.files = [] 
  end 
  SAMPLE_SOURCE_HASH = { 'foo-1.2.3' => SAMPLE_SPEC }
  
  def setup
    @source_index = Gem::SourceIndex.new(SAMPLE_SOURCE_HASH)
  end

  def test_create_from_directory
  end

  def test_search_for_missing_gem_returns_nothing
    gems = @source_index.search("bogusstring")
    assert_equal(gems.size, 0)
  end

  def test_search_empty_cache_returns_nothing
    empty_source_index = Gem::SourceIndex.new({})
    gems = empty_source_index.search("foo")
    assert_equal(gems.size, 0)
  end

  def test_search_with_full_gem_name_returns_gem
    gems = @source_index.search("foo")
    assert_equal(gems.size, 1)
  end

  def test_search_with_full_gem_name_and_version_returns_gem
    gems = @source_index.search("foo", "= 1.2.3")
    assert_equal(gems.size, 1)
  end

  def test_search_with_full_gem_name_and_wrong_version_returns_nothing
    gems = @source_index.search("foo", "= 3.2.1")
    assert_equal(gems.size, 0)
  end

  def test_search_with_full_gem_name_in_mixed_case_returns_gem
    gems = @source_index.search("FOo")
    assert_equal(gems.size, 1,
      %{This is failing because we have duplication between remote_installer and } + 
      %{source_index.rb.  We should factor remote_installer's search logic out } +
      %{into source_index.rb's search and delegate from remote_installer to } +
      %{source_index.rb})
  end

end
