require 'test/unit'
require 'rubygems'
require 'net/http'
require 'yaml'

class RemoteInstallerTest < Test::Unit::TestCase
  class MockHTTPSuccess < Net::HTTPSuccess
    attr_reader :body

    def initialize(body)
      @body = body
    end
  end

  class MockNetHTTP
    def self.get_response(uri)
      response = responses[uri.to_s]
      if not response then
        raise "No response for #{uri.inspect} (we have #{responses.inspect})"
      end
      return response
    end

    class << self
      attr_accessor :responses
    end
  end

  class MockInstaller
    def initialize(gem)
      # TODO
    end

    def install
      # TODO
    end
  end

  class RemoteInstaller < Gem::RemoteInstaller
    include Test::Unit::Assertions

    attr_accessor :expected_destination_files
    attr_accessor :expected_bodies

    def http_class
      return MockNetHTTP
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

  CACHE_SOURCE = "http://www.chadfowler.com:8808"

  def test_get_cache_sources
    @remote_installer = RemoteInstaller.new('foo')
    assert_equal [CACHE_SOURCE], @remote_installer.get_cache_sources
    # TODO
  end

  def test_get_caches
    @remote_installer = RemoteInstaller.new('foo')
  end

  def test_find_latest_valid_package_in_caches(cache)
    @remote_installer = RemoteInstaller.new('foo')
  end

  def test_download_file
    @remote_installer = RemoteInstaller.new('foo')
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
    @remote_installer = RemoteInstaller.new('foo')
    MockNetHTTP.responses = {
      CACHE_SOURCE + "/yaml" => http_success(SAMPLE_CACHE_YAML),
      "#{CACHE_SOURCE}/gems/foo-1.2.3.gem" => http_success(FOO_GEM)
    }
    @remote_installer.expected_destination_files = [File.join(CACHE_DIR, 'foo-1.2.3.gem')]
    @remote_installer.expected_bodies = [FOO_GEM]
    result = @remote_installer.install
    assert_equal nil, result
  end

  def http_success(body)
    return MockHTTPSuccess.new(body)
  end
end

