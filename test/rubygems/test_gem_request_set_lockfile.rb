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

  def test_gem
    a, ad = util_gem 'a', 2

    util_setup_spec_fetcher a

    @fetcher.data["http://gems.example.com/gems/#{a.file_name}"] =
      Gem.read_binary(ad)

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
    a, ad = util_gem 'a', 2, 'b' => '>= 0'
    b, bd = util_gem 'b', 2

    util_setup_spec_fetcher a, b

    @fetcher.data["http://gems.example.com/gems/#{a.file_name}"] =
      Gem.read_binary(ad)
    @fetcher.data["http://gems.example.com/gems/#{b.file_name}"] =
      Gem.read_binary(bd)

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

end

