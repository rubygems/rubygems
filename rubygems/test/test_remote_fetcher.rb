#!/usr/bin/env ruby

require 'test/unit'
require 'zlib'
require 'webrick'
require 'rubygems'

require 'test/mockgemui'
require 'test/yaml_data'

Gem.manage_gems
include WEBrick

class TestRemoteFetcher < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    self.class.start_servers
    self.class.enable_yaml = true
    self.class.enable_zip = false
    ENV['http_proxy'] = nil
    ENV['HTTP_PROXY'] = nil
  end


  def test_no_proxy
    use_ui(MockGemUi.new) do
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", nil)
      assert_equal YAML_DATA, fetcher.fetch_path("/yaml")
      assert_equal YAML_DATA.size, fetcher.size
      source_info = fetcher.source_info
      gems = source_info.search('rake', "= 0.4.11")
      assert_equal 1, gems.size
      assert_equal "rake", gems.first.name
    end
  end
  
  def test_explicit_proxy
    use_ui(MockGemUi.new) do
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", "http://localhost:12345")
      assert_equal PROXY_DATA.size, fetcher.size
      assert_equal PROXY_DATA, fetcher.fetch_path("/yaml")
      source_info = fetcher.source_info
      gems = source_info.search('rake', "= 0.4.2")
      assert_equal 1, gems.size
      assert_equal "rake", gems.first.name
    end
  end
  
  def test_implicit_proxy
    use_ui(MockGemUi.new) do
      ENV['http_proxy'] = 'http://localhost:12345'
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", true)
      assert_equal PROXY_DATA, fetcher.fetch_path("/yaml")
    end
  end
  
  def test_implicit_upper_case_proxy
    use_ui(MockGemUi.new) do
      ENV['HTTP_PROXY'] = 'http://localhost:12345'
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", true)
      assert_equal PROXY_DATA, fetcher.fetch_path("/yaml")
    end
  end
  
  def test_implicit_proxy_no_env
    use_ui(MockGemUi.new) do
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", true)
      assert_equal YAML_DATA, fetcher.fetch_path("/yaml")
    end
  end
  
  def test_zip
    use_ui(MockGemUi.new) do
      self.class.enable_zip = true
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", nil)
      assert_equal YAML_DATA.size, fetcher.size
      zip_data = fetcher.fetch_path("/yaml.Z")
      assert zip_data.size < YAML_DATA.size
    end
  end

  def test_no_zip
    use_ui(MockGemUi.new) do
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", nil)
      assert_error { fetcher.fetch_path("/yaml.Z") }
    end
  end

  def test_yaml_error_on_size
    use_ui(MockGemUi.new) do
      self.class.enable_yaml = false
      fetcher = Gem::RemoteSourceFetcher.new("http://localhost:12344", nil)
      assert_error { fetcher.size }
    end
  end

  def assert_error(exception_class=Exception)
    got_exception = false
    begin
      yield
    rescue exception_class => ex
      got_exception = true
    end
    assert got_exception, "Expected exception conforming to #{exception_class}" 
  end

  class << self
    attr_reader :normal_server, :proxy_server
    attr_accessor :enable_zip, :enable_yaml
    
    def start_servers
      @normal_server ||= start_server(12344, YAML_DATA)
      @proxy_server  ||= start_server(12345, PROXY_DATA)
      @enable_yaml = true
      @enable_zip = false
      sleep 1
    end
    
    private
    
    def start_server(port, data)
      Thread.new do
	begin
	  null_logger = Log.new('/dev/null')
	  s = HTTPServer.new(
	    :Port            => port,
	    :DocumentRoot    => ".",
	    :Logger          => null_logger,
	    :AccessLog       => null_logger
	    )
	  s.mount_proc("/kill") { |req, res| s.shutdown }
	  s.mount_proc("/yaml") { |req, res|
	    if @enable_yaml
	      res.body = data
	      res['Content-Type'] = 'text/plain'
	      res['content-length'] = data.size
	    else
	      res.code = "404"
	      res.body = "<h1>NOT FOUND</h1>"
	      res['Content-Type'] = 'text/html'
	    end
	  }
	  s.mount_proc("/yaml.Z") { |req, res|
	    if @enable_zip
	      res.body = Zlib::Deflate.deflate(data)
	      res['Content-Type'] = 'text/plain'
	    else
	      res.code = "404"
	      res.body = "<h1>NOT FOUND</h1>"
	      res['Content-Type'] = 'text/html'
	    end
	  }
	  s.start
	rescue Exception => ex
	  puts "ERROR during server thread: #{ex.message}"
	end
      end
    end
  end
  
end
