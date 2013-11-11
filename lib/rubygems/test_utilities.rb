require 'tempfile'
require 'rubygems'
require 'rubygems/remote_fetcher'

##
# A fake Gem::RemoteFetcher for use in tests or to avoid real live HTTP
# requests when testing code that uses RubyGems.
#
# Example:
#
#   @fetcher = Gem::FakeFetcher.new
#   @fetcher.data['http://gems.example.com/yaml'] = source_index.to_yaml
#   Gem::RemoteFetcher.fetcher = @fetcher
#
#   # invoke RubyGems code
#
#   paths = @fetcher.paths
#   assert_equal 'http://gems.example.com/yaml', paths.shift
#   assert paths.empty?, paths.join(', ')
#
# See RubyGems' tests for more examples of FakeFetcher.

class Gem::FakeFetcher

  attr_reader :data
  attr_reader :last_request
  attr_reader :api_endpoints
  attr_accessor :paths

  def initialize
    @data = {}
    @paths = []
    @api_endpoints = {}
  end

  def api_endpoint(uri)
    @api_endpoints[uri] || uri
  end

  def find_data(path)
    if URI === path and "URI::#{path.scheme.upcase}" != path.class.name then
      raise ArgumentError,
        "mismatch for scheme #{path.scheme} and class #{path.class}"
    end

    path = path.to_s
    @paths << path
    raise ArgumentError, 'need full URI' unless path =~ %r'^https?://'

    unless @data.key? path then
      raise Gem::RemoteFetcher::FetchError.new("no data for #{path}", path)
    end

    @data[path]
  end

  def fetch_path path, mtime = nil, head = false
    data = find_data(path)

    if data.respond_to?(:call) then
      data.call
    else
      if path.to_s =~ /gz$/ and not data.nil? and not data.empty? then
        data = Gem.gunzip data
      end

      data
    end
  end

  def cache_update_path uri, path = nil, update = true
    if data = fetch_path(uri)
      open(path, 'wb') { |io| io.write data } if path and update
      data
    else
      Gem.read_binary(path) if path
    end
  end

  # Thanks, FakeWeb!
  def open_uri_or_path(path)
    data = find_data(path)
    body, code, msg = data

    response = Net::HTTPResponse.send(:response_class, code.to_s).new("1.0", code.to_s, msg)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def request(uri, request_class, last_modified = nil)
    data = find_data(uri)
    body, code, msg = data

    @last_request = request_class.new uri.request_uri
    yield @last_request if block_given?

    response = Net::HTTPResponse.send(:response_class, code.to_s).new("1.0", code.to_s, msg)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def fetch_size(path)
    path = path.to_s
    @paths << path

    raise ArgumentError, 'need full URI' unless path =~ %r'^http://'

    unless @data.key? path then
      raise Gem::RemoteFetcher::FetchError.new("no data for #{path}", path)
    end

    data = @data[path]

    data.respond_to?(:call) ? data.call : data.length
  end

  def download spec, source_uri, install_dir = Gem.dir
    name = File.basename spec.cache_file
    path = if Dir.pwd == install_dir then # see fetch_command
             install_dir
           else
             File.join install_dir, "cache"
           end

    path = File.join path, name

    if source_uri =~ /^http/ then
      File.open(path, "wb") do |f|
        f.write fetch_path(File.join(source_uri, "gems", name))
      end
    else
      FileUtils.cp source_uri, path
    end

    path
  end

  def download_to_cache dependency
    found, _ = Gem::SpecFetcher.fetcher.spec_for_dependency dependency

    return if found.empty?

    spec, source = found.first

    download spec, source.uri.to_s
  end

end

# :stopdoc:
class Gem::RemoteFetcher

  def self.fetcher=(fetcher)
    @fetcher = fetcher
  end

end
# :startdoc:

##
# The SpecFetcherSetup allows easy setup of a remote source in RubyGems tests:
#
#   spec_fetcher do |f|
#     f.gem  'a', 1
#     f.spec 'a', 2
#     f.gem  'b', 1' 'a' => '~> 1.0'
#     f.clear
#   end
#
# The above declaration creates two gems, a-1 and b-1, with a dependency from
# b to a.  The declaration creates an additional spec a-2, but no gem for it
# (so it cannot be installed).
#
# After the gems are created they are removed from Gem.dir.

class Gem::TestCase::SpecFetcherSetup

  ##
  # Executes a SpecFetcher setup block.  Yields an instance then creates the
  # gems and specifications defined in the instance.

  def self.declare test
    setup = new test

    yield setup

    setup.execute
  end

  def initialize test # :nodoc:
    @test  = test

    @clear   = false
    @fetcher = @test.fetcher
    @gems    = {}
  end

  ##
  # Removes any created gems or specifications from Gem.dir (the default
  # install location).

  def clear
    @clear = true
  end

  ##
  # Creates any defined gems or specifications

  def execute # :nodoc:
    @test.util_setup_fake_fetcher unless @test.fetcher
    @test.util_setup_spec_fetcher(*@gems.keys)

    @gems.each do |spec, gem|
      next unless gem

      @fetcher.data["http://gems.example.com/gems/#{spec.file_name}"] =
        Gem.read_binary(gem)
    end

    @test.util_clear_gems if @clear
  end

  ##
  # Creates a gem with +name+, +version+ and +deps+.  The created gem can be
  # downloaded and installed.
  #
  # The specification will be yielded before gem creation for customization,
  # but only the block or the dependencies may be set, not both.

  def gem name, version, dependencies = nil, &block
    spec, gem = @test.util_gem name, version, dependencies, &block

    @gems[spec] = gem

    spec
  end

  ##
  # Creates a spec with +name+, +version+ and +deps+.  The created gem can be
  # downloaded and installed.
  #
  # The specification will be yielded before creation for customization,
  # but only the block or the dependencies may be set, not both.

  def spec name, version, dependencies = nil, &block
    spec = @test.util_spec name, version, dependencies, &block

    @gems[spec] = nil

    spec
  end

end

##
# A StringIO duck-typed class that uses Tempfile instead of String as the
# backing store.
#
# This is available when rubygems/test_utilities is required.
#--
# This class was added to flush out problems in Rubinius' IO implementation.

class TempIO < Tempfile

  ##
  # Creates a new TempIO that will be initialized to contain +string+.

  def initialize(string = '')
    super "TempIO"
    binmode
    write string
    rewind
  end

  ##
  # The content of the TempIO as a String.

  def string
    flush
    Gem.read_binary path
  end
end

