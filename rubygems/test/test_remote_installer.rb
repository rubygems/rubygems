require 'test/unit'
require 'rubygems'
Gem::manage_gems
require 'net/http'
require 'yaml'

class MockFetcher
  def initialize(uri)
    @uri = uri
  end

  def size
    1000
  end
  
  def source_info
    if @uri =~ /non.existent.url/
      fail Gem::RemoteSourceException,
	"Error fetching remote gem cache: Mock Socket Exception"
    end
    result = {
      'cache' => {
	'foo-1.2.3' => Gem::Specification.new do |s|
	  s.name = 'foo'
	  s.version = "1.2.3"
	  s.summary = "This is a cool package"
	end
      }
    }
    result['size'] = result['cache'].to_yaml.size
    result
  end
end

class TestRemoteInstaller < Test::Unit::TestCase

  PROPER_SOURCES = %w( http://gems.rubyforge.org )

  def setup
    @installer = Gem::RemoteInstaller.new
    @installer.instance_variable_set("@fetcher_class", MockFetcher)
  end

  def test_create
    assert_not_nil(@installer)
  end
  
  # Make sure that the installer knows the proper list of places to go
  # to get packages.
  def test_source_list
    assert_equal PROPER_SOURCES, @installer.sources
  end

  def test_source_info
    source_hash = @installer.source_info(Gem.dir)
    assert source_hash.has_key?("http://gems.rubyforge.org")
    assert_equal 1, source_hash.size
    gem_hash = source_hash['http://gems.rubyforge.org']
    spec = gem_hash['cache']['foo-1.2.3']
    assert_equal 'foo', spec.name
    assert_equal '1.2.3', spec.version.to_s
    assert_equal gem_hash['cache'].to_yaml.size, gem_hash['size']
  end

  def test_missing_source_exception
    @installer.instance_variable_set("@sources", ["http://non.existent.url"])
    assert_raise(Gem::RemoteSourceException) {
      info = @installer.source_info(Gem.dir)
    }
  end
end

# This test suite has a number of TODOs in the test cases.  The
# TestRemoteInstaller test suite is a reworking of this class from
# scratch.
class RemoteInstallerTest < Test::Unit::TestCase
  class MockInstaller
    def initialize(gem)
      # TODO
    end

    def install(force, directory, stub)
      # TODO
    end
  end

  class RemoteInstaller < Gem::RemoteInstaller
    include Test::Unit::Assertions

    attr_accessor :expected_destination_files
    attr_accessor :expected_bodies
    attr_accessor :caches
    attr_accessor :responses

    def source_info(install_dir)
      @caches
    end

    def fetch(uri)
      @reponses ||= {}
      @responses[uri]
    end

    def write_gem_to_file(body, destination_file)
      expected_destination_file = expected_destination_files.pop
      expected_body = expected_bodies.pop
      assert_equal expected_body, body, "Unexpected body"
      assert_equal expected_destination_file, destination_file, "Unexpected destination file"
    end

    def new_installer(gem)
      return MockInstaller.new(gem)
    end
  end

  CACHE_SOURCES = ["http://gems.rubyforge.org"]

  def test_sources
    @remote_installer = RemoteInstaller.new
    assert_equal CACHE_SOURCES, @remote_installer.sources
    # TODO
  end

  def test_source_info
    @remote_installer = RemoteInstaller.new
  end

  def test_find_latest_valid_package_in_caches(cache)
    @remote_installer = RemoteInstaller.new
  end

  def test_download_file
    @remote_installer = RemoteInstaller.new
  end

  SAMPLE_SPEC = Gem::Specification.new do |s|
    s.name = 'foo'
    s.version = "1.2.3"
    s.platform = Gem::Platform::RUBY
    s.summary = "This is a cool package"
    s.files = []
  end
  SAMPLE_CACHE = { 'foo-1.2.3' => SAMPLE_SPEC }
  SAMPLE_CACHE_YAML = SAMPLE_CACHE.to_yaml

  FOO_GEM = '' # TODO
  CACHE_DIR = File.join(Gem.dir, 'cache')

  def test_install
    @remote_installer = RemoteInstallerTest::RemoteInstaller.new
    @remote_installer.responses = {
      CACHE_SOURCES[0] + "/yaml" => SAMPLE_CACHE_YAML,
      "#{CACHE_SOURCES[0]}/gems/foo-1.2.3.gem" => FOO_GEM
    }
    @remote_installer.caches = { CACHE_SOURCES[0]  => SAMPLE_CACHE }
    @remote_installer.expected_destination_files = [File.join(CACHE_DIR, 'foo-1.2.3.gem')]
    @remote_installer.expected_bodies = [FOO_GEM]

    result = @remote_installer.install('foo')
    assert_equal [nil], result
  end

end

