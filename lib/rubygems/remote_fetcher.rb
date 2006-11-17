require 'net/http'
require 'uri'
require 'yaml'
require 'zlib'

require 'rubygems'
require 'rubygems/user_interaction'

##
# Represents an error communicating via HTTP.

class Gem::RemoteSourceException < Gem::Exception; end

##
# RemoteFetcher handles the details of fetching gems and gem information from
# a remote source.

class Gem::RemoteFetcher

  include Gem::UserInteraction

  # Sent by the client when it is done with all the sources, allowing any
  # cleanup activity to take place.
  def self.finish
    # Nothing to do
  end

  # Initialize a remote fetcher using the source URI and possible proxy
  # information.
  #
  # +proxy+
  # * [String]: explicit specification of proxy; overrides any environment
  #             variable setting
  # * nil: respect environment variables (HTTP_PROXY, HTTP_PROXY_USER,
  #        HTTP_PROXY_PASS)
  # * <tt>:no_proxy</tt>: ignore environment variables and _don't_ use a proxy
  def initialize(source_uri, proxy)
    @uri = normalize_uri(source_uri)
    @proxy_uri =
      case proxy
      when :no_proxy
        nil
      when nil
        env_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        uri = env_proxy ? URI.parse(env_proxy) : nil
        if uri and uri.user.nil? and uri.password.nil?
          #Probably we have http_proxy_* variables?
          uri.user = escape(ENV['http_proxy_user'] || ENV['HTTP_PROXY_USER'])
          uri.password = escape(ENV['http_proxy_pass'] || ENV['HTTP_PROXY_PASS'])
        end
        uri
      else
        URI.parse(proxy.to_str)
      end
  end

  # The uncompressed +size+ of the source's directory (e.g. source info).
  def size
    @size ||= get_size("/yaml")
  end

  # Fetch the data from the source at the given path.
  def fetch_path(path="")
    read_data(@uri + path)
  end

  # Get the source index from the gem source.  The source index is a directory
  # of the gems available on the source, formatted as a Gem::Cache object.
  # The cache object allows easy searching for gems by name and version
  # requirement.
  #
  # Notice that the gem specs in the cache are adequate for searches and
  # queries, but may have some information elided (hence "abbreviated").
  def source_index
    say "Bulk updating Gem source index for: #{@uri}"
    begin
      require 'zlib'
      yaml_spec = fetch_path("/yaml.Z")
      yaml_spec = Zlib::Inflate.inflate(yaml_spec)
    rescue
      yaml_spec = nil
    end
    begin
      yaml_spec = fetch_path("/yaml") unless yaml_spec
      convert_spec(yaml_spec)
    rescue SocketError => e
      raise Gem::RemoteSourceException.new("Error fetching remote gem cache: #{e.to_s}")
    end
  end

  private
  def escape(str)
    return unless str
    URI.escape(str)
  end

  def unescape(str)
    return unless str
    URI.unescape(str)
  end

  # Normalize the URI by adding "http://" if it is missing.
  def normalize_uri(uri)
    (uri =~ /^(https?|ftp|file):/) ? uri : "http://#{uri}"
  end

  # Connect to the source host/port, using a proxy if needed.
  def connect_to(host, port)
    if @proxy_uri
      Net::HTTP::Proxy(@proxy_uri.host, @proxy_uri.port, unescape(@proxy_uri.user), unescape(@proxy_uri.password)).new(host, port)
    else
      Net::HTTP.new(host, port)
    end
  end

  # Get the size of the (non-compressed) data from the source at the given
  # path.
  def get_size(path)
    read_size(@uri + path)
  end

  # Read the size of the (source based) URI using an HTTP HEAD command.
  def read_size(uri)
    return File.size(get_file_uri_path(uri)) if is_file_uri(uri)
    require 'net/http'
    require 'uri'
    u = URI.parse(uri)
    http = connect_to(u.host, u.port)
    path = (u.path == "") ? "/" : u.path
    resp = http.head(path)
    raise Gem::RemoteSourceException, "HTTP Response #{resp.code}" if resp.code !~ /^2/
    resp['content-length'].to_i
  end

  # Read the data from the (source based) URI.
  def read_data(uri)
    begin
      open_uri_or_path(uri) do |input|
        input.read
      end
    rescue
      old_uri = uri
      uri = uri.downcase
      retry if old_uri != uri
      raise
    end
  end

  # Read the data from the (source based) URI, but if it is a file:// URI,
  # read from the filesystem instead.
  def open_uri_or_path(uri, &block)
    require 'rubygems/open-uri'
    if is_file_uri(uri)
      open(get_file_uri_path(uri), &block)
    else
      connection_options = {"User-Agent" => "RubyGems/#{Gem::RubyGemsVersion}"}
      if @proxy_uri
        http_proxy_url = "#{@proxy_uri.scheme}://#{@proxy_uri.host}:#{@proxy_uri.port}"  
        connection_options[:proxy_http_basic_authentication] = [http_proxy_url, unescape(@proxy_uri.user)||'', unescape(@proxy_uri.password)||'']
      end

      open(uri, connection_options, &block)
    end
  end

  # Checks if the provided string is a file:// URI.
  def is_file_uri(uri)
    uri =~ %r{\Afile://}
  end

  # Given a file:// URI, returns its local path.
  def get_file_uri_path(uri)
    uri.sub(%r{\Afile://}, '')
  end

  # Convert the yamlized string spec into a real spec (actually, these are
  # hashes of specs.).
  def convert_spec(yaml_spec)
    YAML.load(reduce_spec(yaml_spec)) or
      raise "Didn't get a valid YAML document"
  end

  # This reduces the source spec in size so that YAML bugs with large data
  # sets will be dodged.  Obviously this is a workaround, but it allows Gems
  # to continue to work until the YAML bug is fixed.  
  def reduce_spec(yaml_spec)
    result = ""
    state = :copy
    yaml_spec.each do |line|
      if state == :copy && line =~ /^\s+files:\s*$/
        state = :skip
        result << line.sub(/$/, " []")
      elsif state == :skip
        if line !~ /^\s+-/
          state = :copy
        end
      end
      result << line if state == :copy
    end
    result
  end

end

