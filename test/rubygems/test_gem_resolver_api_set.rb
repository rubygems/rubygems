require 'rubygems/test_case'

class TestGemResolverAPISet < Gem::TestCase

  def setup
    super

    @DR = Gem::Resolver
  end

  def test_initialize
    set = @DR::APISet.new

    assert_equal URI('https://rubygems.org/api/v1/dependencies'), set.dep_uri
    assert_equal URI('https://rubygems.org'),                     set.uri
    assert_equal Gem::Source.new(URI('https://rubygems.org')),    set.source
  end

  def test_initialize_uri
    set = @DR::APISet.new URI "#{@gem_repo}/api/v1/dependencies"

    assert_equal URI("#{@gem_repo}/api/v1/dependencies"), set.dep_uri
    assert_equal URI("#{@gem_repo}"),                     set.uri
  end

end

