require 'rubygems/test_case'
require 'rubygems/request_set'
require 'rubygems/request_set/lockfile'

class TestGemRequestSetLockfile < Gem::TestCase

  def setup
    super

    Gem::RemoteFetcher.fetcher = @fetcher = Gem::FakeFetcher.new

    util_set_arch 'i686-darwin8.10.1'

    @set = Gem::RequestSet.new

    @vendor_set = Gem::DependencyResolver::VendorSet.new

    @set.instance_variable_set :@vendor_set, @vendor_set

    @gem_deps_file = 'gem.deps.rb'

    @lockfile = Gem::RequestSet::Lockfile.new @set, @gem_deps_file
  end

  def spec_fetcher
    gems = {}

    gem_maker = Object.new
    gem_maker.instance_variable_set :@test,  self
    gem_maker.instance_variable_set :@gems,  gems

    def gem_maker.gem name, version, dependencies = nil, &block
      spec, gem = @test.util_gem name, version, dependencies, &block

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
      s.gem 'a', 2, 'c' => '>= 0', 'b' => '>= 0'
      s.gem 'b', 2
      s.gem 'c', 2
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b
      c
    b (2)
    c (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_dependency_non_default
    spec_fetcher do |s|
      s.gem 'a', 2, 'b' => '>= 1'
      s.gem 'b', 2
    end

    @set.gem 'b'
    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b (>= 1)
    b (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
  b
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
    a (2)
      b
    b (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a (>= 1)
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_path
    name, version, directory = vendor_gem

    @vendor_set.add_vendor_gem name, directory

    @set.gem 'a'

    expected = <<-LOCKFILE
PATH
  remote: #{directory}
  specs:
    #{name} (#{version})

GEM

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a!
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_path_absolute
    name, version, directory = vendor_gem

    @vendor_set.add_vendor_gem name, File.expand_path(directory)

    @set.gem 'a'

    expected = <<-LOCKFILE
PATH
  remote: #{directory}
  specs:
    #{name} (#{version})

GEM

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a!
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_gem_platform
    spec_fetcher do |s|
      s.gem 'a', 2 do |spec|
        spec.platform = Gem::Platform.local
      end
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2-#{Gem::Platform.local})

PLATFORMS
  #{Gem::Platform.local}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

end

