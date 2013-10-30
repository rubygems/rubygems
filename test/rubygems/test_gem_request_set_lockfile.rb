require 'rubygems/test_case'
require 'rubygems/request_set'
require 'rubygems/request_set/lockfile'

class TestGemRequestSetLockfile < Gem::TestCase

  def setup
    super

    Gem::RemoteFetcher.fetcher = @fetcher = Gem::FakeFetcher.new

    util_set_arch 'i686-darwin8.10.1'

    @set = Gem::RequestSet.new

    @lockfile = Gem::RequestSet::Lockfile.new @set
  end

  def spec_fetcher
    gems = {}

    gem_maker = Object.new
    gem_maker.instance_variable_set :@test,  self
    gem_maker.instance_variable_set :@gems,  gems

    def gem_maker.gem name, version, dependencies = nil
      spec, gem = @test.util_gem name, version, dependencies

      @gems[spec] = gem

      spec
    end

    yield gem_maker

    util_setup_spec_fetcher *gems.keys

    gems.each do |spec, gem|
      @fetcher.data["http://gems.example.com/gems/#{spec.file_name}"] =
        Gem.read_binary(gem)
    end
  end

  def test_gem
    spec_fetcher do |s|
      s.gem 'a', 2
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_dependency
    spec_fetcher do |s|
      s.gem 'a', 2, 'b' => '>= 0'
      s.gem 'b', 2
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    b (2)
    a (2)
      b

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_dependency_requirement
    spec_fetcher do |s|
      s.gem 'a', 2, 'b' => '>= 0'
      s.gem 'b', 2
    end

    @set.gem 'a', '>= 1'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    b (2)
    a (2)
      b

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a (>= 1)
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

end

