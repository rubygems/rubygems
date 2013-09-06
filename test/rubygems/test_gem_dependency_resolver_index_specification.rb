require 'rubygems/test_case'
require 'rubygems/dependency_resolver'

class TestGemDependencyResolverIndexSpecification < Gem::TestCase

  def test_initialize
    set     = Gem::DependencyResolver::IndexSet.new
    source  = Gem::Source.new @gem_repo
    version = Gem::Version.new '3.0.3'

    spec = Gem::DependencyResolver::IndexSpecification.new(
      set, 'rails', version, source, Gem::Platform::RUBY)

    assert_equal 'rails',             spec.name
    assert_equal version,             spec.version
    assert_equal Gem::Platform::RUBY, spec.platform

    assert_equal source, spec.source
  end

end

