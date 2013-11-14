require 'rubygems/test_case'
require 'rubygems/dependency_resolver'

class TestGemDependencyResolverGitSet < Gem::TestCase

  def setup
    super

    @set = Gem::DependencyResolver::GitSet.new
  end

  def test_add_git_gem
    name, version, repository, = git_gem

    @set.add_git_gem name, repository, 'master'

    spec = @set.load_spec name, version, Gem::Platform::RUBY, nil

    assert_equal "#{name}-#{version}", spec.full_name
  end

  def test_find_all
    name, version, repository, = git_gem

    @set.add_git_gem name, repository, 'master'

    dependency = dep 'a', '~> 1.0'

    found = @set.find_all dependency

    spec = @set.load_spec name, version, Gem::Platform::RUBY, nil

    source = Gem::Source::Git.new name, repository, 'master'

    assert_equal [spec], found
  end

  def test_prefetch
    name, _, repository, = git_gem

    @set.add_git_gem name, repository, 'master'

    dependency = dep name
    req = Gem::DependencyResolver::ActivationRequest.new dependency, nil
    reqs = Gem::DependencyResolver::RequirementList.new
    reqs.add req

    @set.prefetch reqs

    refute_empty @set.specs
  end

  def test_prefetch_filter
    name, _, repository, = git_gem

    @set.add_git_gem name, repository, 'master'

    dependency = dep 'b'
    req = Gem::DependencyResolver::ActivationRequest.new dependency, nil
    reqs = Gem::DependencyResolver::RequirementList.new
    reqs.add req

    @set.prefetch reqs

    assert_empty @set.specs
  end

end

