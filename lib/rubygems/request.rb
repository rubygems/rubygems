require 'net/http'
require 'thread'
require 'time'
require 'rubygems/user_interaction'
require 'monitor'

class Gem::Request

  include Gem::UserInteraction

  attr_reader :proxy_uri, :cert_files

  def initialize(uri, request_class, last_modified, proxy)
    @uri = uri
    @request_class = request_class
    @last_modified = last_modified
    @requests = Hash.new 0
    @user_agent = user_agent

    @proxy_uri =
      case proxy
      when :no_proxy then nil
      when nil       then get_proxy_from_env uri.scheme
      when URI::HTTP then proxy
      else URI.parse(proxy)
      end

    @cert_files = get_cert_files

    @connection_pool = ConnectionPools.new @proxy_uri, @cert_files
  end

  class ConnectionPools # :nodoc:
    @client = Net::HTTP

    class << self; attr_accessor :client; end

    def initialize proxy_uri, cert_files
      @proxy_uri  = proxy_uri
      @cert_files = cert_files
      @pools      = {}
      @pool_mutex = Mutex.new
    end

    def checkout_connection_for uri
      pool_for(uri).checkout
    end

    def checkin_connection_for uri, connection
      pool_for(uri).checkin connection
    end

    ###
    # A connection "pool" that only manages one connection for now.
    # Provides thread safe `checkout` and `checkin` methods.  The
    # pool consists of one connection that corresponds to `http_args`.
    # This class is private, do not use it.
    class HTTPPool # :nodoc:
      def initialize http_args, cert_files
        @http_args  = http_args
        @cert_files = cert_files
        @conn       = false
        @lock       = Monitor.new
        @cv         = @lock.new_cond
      end

      def checkout
        @lock.synchronize do
          if @conn.nil?
            @cv.wait_while { @conn.nil? }
            conn, @conn = @conn, nil
            conn
          else
            conn = @conn || make_connection
            @conn = nil
            conn
          end
        end
      end

      def checkin connection
        @lock.synchronize do
          @conn = connection
          @cv.broadcast
        end
      end

      private

      def make_connection
        setup_connection ConnectionPools.client.new(*@http_args)
      end

      def setup_connection connection
        connection.start
        connection
      end
    end

    class HTTPSPool < HTTPPool # :nodoc:
      private

      def setup_connection connection
        Gem::Request.configure_connection_for_https(connection, @cert_files)
        super
      end
    end

    private

    def pool_for uri
      http_args = net_http_args(uri, @proxy_uri)
      key       = http_args + [https?(uri)]
      @pool_mutex.synchronize do
        @pools[key] ||= if https?(uri)
                          HTTPSPool.new(http_args, @cert_files)
                        else
                          HTTPPool.new(http_args, @cert_files)
                        end
      end
    end

    ##
    # Returns list of no_proxy entries (if any) from the environment

    def get_no_proxy_from_env
      env_no_proxy = ENV['no_proxy'] || ENV['NO_PROXY']

      return [] if env_no_proxy.nil?  or env_no_proxy.empty?

      env_no_proxy.split(/\s*,\s*/)
    end

    def https? uri
      uri.scheme.downcase == 'https'
    end

    def no_proxy? host, env_no_proxy
      host = host.downcase
      env_no_proxy.each do |pattern|
        pattern = pattern.downcase
        return true if host[-pattern.length, pattern.length ] == pattern
      end
      return false
    end

    def net_http_args uri, proxy_uri
      net_http_args = [uri.host, uri.port]

      if proxy_uri and not no_proxy?(uri.host, get_no_proxy_from_env) then
        net_http_args + [
          proxy_uri.host,
          proxy_uri.port,
          Gem::UriFormatter.new(proxy_uri.user).unescape,
          Gem::UriFormatter.new(proxy_uri.password).unescape,
        ]
      else
        net_http_args
      end
    end
  end

  def get_cert_files
    pattern = File.expand_path("./ssl_certs/*.pem", File.dirname(__FILE__))
    Dir.glob(pattern)
  end
  private :get_cert_files

  def self.configure_connection_for_https(connection, cert_files)
    require 'net/https'
    connection.use_ssl = true
    connection.verify_mode =
      Gem.configuration.ssl_verify_mode || OpenSSL::SSL::VERIFY_PEER
    store = OpenSSL::X509::Store.new

    if Gem.configuration.ssl_client_cert then
      pem = File.read Gem.configuration.ssl_client_cert
      connection.cert = OpenSSL::X509::Certificate.new pem
      connection.key = OpenSSL::PKey::RSA.new pem
    end

    store.set_default_paths
    cert_files.each do |ssl_cert_file|
      store.add_file ssl_cert_file
    end
    if Gem.configuration.ssl_ca_cert
      if File.directory? Gem.configuration.ssl_ca_cert
        store.add_path Gem.configuration.ssl_ca_cert
      else
        store.add_file Gem.configuration.ssl_ca_cert
      end
    end
    connection.cert_store = store
    connection
  rescue LoadError => e
    raise unless (e.respond_to?(:path) && e.path == 'openssl') ||
                 e.message =~ / -- openssl$/

    raise Gem::Exception.new(
            'Unable to require openssl, install OpenSSL and rebuild ruby (preferred) or use non-HTTPS sources')
  end

  ##
  # Creates or an HTTP connection based on +uri+, or retrieves an existing
  # connection, using a proxy if needed.

  def connection_for(uri)
    @connection_pool.checkout_connection_for uri
  rescue defined?(OpenSSL::SSL) ? OpenSSL::SSL::SSLError : Errno::EHOSTDOWN,
         Errno::EHOSTDOWN => e
    raise Gem::RemoteFetcher::FetchError.new(e.message, uri)
  end

  def fetch
    request = @request_class.new @uri.request_uri

    unless @uri.nil? || @uri.user.nil? || @uri.user.empty? then
      request.basic_auth Gem::UriFormatter.new(@uri.user).unescape,
                         Gem::UriFormatter.new(@uri.password).unescape
    end

    request.add_field 'User-Agent', @user_agent
    request.add_field 'Connection', 'keep-alive'
    request.add_field 'Keep-Alive', '30'

    if @last_modified then
      request.add_field 'If-Modified-Since', @last_modified.httpdate
    end

    yield request if block_given?

    connection = connection_for @uri

    retried = false
    bad_response = false

    begin
      @requests[connection.object_id] += 1

      verbose "#{request.method} #{@uri}"

      file_name = File.basename(@uri.path)
      # perform download progress reporter only for gems
      if request.response_body_permitted? && file_name =~ /\.gem$/
        reporter = ui.download_reporter
        response = connection.request(request) do |incomplete_response|
          if Net::HTTPOK === incomplete_response
            reporter.fetch(file_name, incomplete_response.content_length)
            downloaded = 0
            data = ''

            incomplete_response.read_body do |segment|
              data << segment
              downloaded += segment.length
              reporter.update(downloaded)
            end
            reporter.done
            if incomplete_response.respond_to? :body=
              incomplete_response.body = data
            else
              incomplete_response.instance_variable_set(:@body, data)
            end
          end
        end
      else
        response = connection.request request
      end

      verbose "#{response.code} #{response.message}"

    rescue Net::HTTPBadResponse
      verbose "bad response"

      reset connection

      raise Gem::RemoteFetcher::FetchError.new('too many bad responses', @uri) if bad_response

      bad_response = true
      retry
    # HACK work around EOFError bug in Net::HTTP
    # NOTE Errno::ECONNABORTED raised a lot on Windows, and make impossible
    # to install gems.
    rescue EOFError, Timeout::Error,
           Errno::ECONNABORTED, Errno::ECONNRESET, Errno::EPIPE

      requests = @requests[connection.object_id]
      verbose "connection reset after #{requests} requests, retrying"

      raise Gem::RemoteFetcher::FetchError.new('too many connection resets', @uri) if retried

      reset connection

      retried = true
      retry
    ensure
      @connection_pool.checkin_connection_for @uri, connection
    end

    response
  end

  ##
  # Returns a proxy URI for the given +scheme+ if one is set in the
  # environment variables.

  def get_proxy_from_env scheme = 'http'
    _scheme = scheme.downcase
    _SCHEME = scheme.upcase
    env_proxy = ENV["#{_scheme}_proxy"] || ENV["#{_SCHEME}_PROXY"]

    no_env_proxy = env_proxy.nil? || env_proxy.empty?

    return get_proxy_from_env 'http' if no_env_proxy and _scheme != 'http'
    return nil                       if no_env_proxy

    uri = URI(Gem::UriFormatter.new(env_proxy).normalize)

    if uri and uri.user.nil? and uri.password.nil? then
      user     = ENV["#{_scheme}_proxy_user"] || ENV["#{_SCHEME}_PROXY_USER"]
      password = ENV["#{_scheme}_proxy_pass"] || ENV["#{_SCHEME}_PROXY_PASS"]

      uri.user     = Gem::UriFormatter.new(user).escape
      uri.password = Gem::UriFormatter.new(password).escape
    end

    uri
  end

  ##
  # Resets HTTP connection +connection+.

  def reset(connection)
    @requests.delete connection.object_id

    connection.finish
    connection.start
  end

  def user_agent
    ua = "RubyGems/#{Gem::VERSION} #{Gem::Platform.local}"

    ruby_version = RUBY_VERSION
    ruby_version += 'dev' if RUBY_PATCHLEVEL == -1

    ua << " Ruby/#{ruby_version} (#{RUBY_RELEASE_DATE}"
    if RUBY_PATCHLEVEL >= 0 then
      ua << " patchlevel #{RUBY_PATCHLEVEL}"
    elsif defined?(RUBY_REVISION) then
      ua << " revision #{RUBY_REVISION}"
    end
    ua << ")"

    ua << " #{RUBY_ENGINE}" if defined?(RUBY_ENGINE) and RUBY_ENGINE != 'ruby'

    ua
  end

end

