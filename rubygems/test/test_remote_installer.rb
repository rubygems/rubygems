require 'test/unit'
require 'rubygems'
Gem::manage_gems
require 'net/http'
require 'yaml'

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

    def get_caches(sources)
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

  def test_get_cache_sources
    @remote_installer = RemoteInstaller.new
    assert_equal CACHE_SOURCES, @remote_installer.get_cache_sources
    # TODO
  end

  def test_get_caches
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

