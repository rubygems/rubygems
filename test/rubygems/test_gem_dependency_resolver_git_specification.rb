require 'rubygems/test_case'
require 'rubygems/dependency_resolver'

class TestGemDependencyResolverGitSpecification < Gem::TestCase

  def setup
    super

    @set  = Gem::DependencyResolver::GitSet.new
    @spec = Gem::Specification.new 'a', 1
  end

  def test_equals2
    g_spec_a = Gem::DependencyResolver::GitSpecification.new @set, @spec

    assert_equal g_spec_a, g_spec_a

    spec_b = Gem::Specification.new 'b', 1
    g_spec_b = Gem::DependencyResolver::GitSpecification.new @set, spec_b

    refute_equal g_spec_a, g_spec_b

    g_set = Gem::DependencyResolver::GitSet.new
    g_spec_s = Gem::DependencyResolver::GitSpecification.new g_set, @spec

    refute_equal g_spec_a, g_spec_s

    i_set  = Gem::DependencyResolver::IndexSet.new
    source = Gem::Source.new @gem_repo
    i_spec = Gem::DependencyResolver::IndexSpecification.new(
      i_set, 'a', v(1), source, Gem::Platform::RUBY)

    refute_equal g_spec_a, i_spec
  end

end

