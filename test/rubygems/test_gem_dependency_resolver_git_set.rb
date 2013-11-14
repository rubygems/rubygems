require 'rubygems/test_case'
require 'rubygems/dependency_resolver'

class TestGemDependencyResolverGitSet < Gem::TestCase

  def setup
    super

    @set = Gem::DependencyResolver::GitSet.new
  end

  def test_add_git_gem
    name, version, repository = git_gem

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

end

