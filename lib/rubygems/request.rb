class Gem::Request
  def initialize(uri, request_class, last_modified, proxy)
    @uri = uri
    @request_class = request_class
    @last_modified = last_modified
    @requests = Hash.new 0
    @connections = {}
    @user_agent = user_agent

    @proxy_uri =
      case proxy
      when :no_proxy then nil
      when nil then get_proxy_from_env
      when URI::HTTP then proxy
      else URI.parse(proxy)
      end
  end

  def fetch
    request = @request_class.new @uri.request_uri

    unless @uri.nil? || @uri.user.nil? || @uri.user.empty? then
      request.basic_auth @uri.user, @uri.password
    end

    request.add_field 'User-Agent', @user_agent
    request.add_field 'Connection', 'keep-alive'
    request.add_field 'Keep-Alive', '30'

    if @last_modified then
      @last_modified = @last_modified.utc
      request.add_field 'If-Modified-Since', @last_modified.rfc2822
    end

    yield request if block_given?

    connection = connection_for @uri

    retried = false
    bad_response = false

    begin
      @requests[connection.object_id] += 1

      say "#{request.method} #{@uri}" if
        Gem.configuration.really_verbose

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

      say "#{response.code} #{response.message}" if
        Gem.configuration.really_verbose

    rescue Net::HTTPBadResponse
      say "bad response" if Gem.configuration.really_verbose

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
      say "connection reset after #{requests} requests, retrying" if
        Gem.configuration.really_verbose

      raise Gem::RemoteFetcher::FetchError.new('too many connection resets', @uri) if retried

      reset connection

      retried = true
      retry
    end

    response
  end

  ##
  # Resets HTTP connection +connection+.

  def reset(connection)
    @requests.delete connection.object_id

    connection.finish
    connection.start
  end

  ##
  # Creates or an HTTP connection based on +uri+, or retrieves an existing
  # connection, using a proxy if needed.

  def connection_for(uri)
    net_http_args = [uri.host, uri.port]

    if @proxy_uri then
      net_http_args += [
        @proxy_uri.host,
        @proxy_uri.port,
        @proxy_uri.user,
        @proxy_uri.password
      ]
    end

    connection_id = [Thread.current.object_id, *net_http_args].join ':'
    @connections[connection_id] ||= Net::HTTP.new(*net_http_args)
    connection = @connections[connection_id]

    if uri.scheme == 'https' and not connection.started? then
      require 'net/https'
      connection.use_ssl = true
      connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    connection.start unless connection.started?

    connection
  rescue Errno::EHOSTDOWN => e
    raise Gem::RemoteFetcher::FetchError.new(e.message, uri)
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

  ##
  # Returns an HTTP proxy URI if one is set in the environment variables.

  def get_proxy_from_env
    env_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']

    return nil if env_proxy.nil? or env_proxy.empty?

    uri = URI.parse(normalize_uri(env_proxy))

    if uri and uri.user.nil? and uri.password.nil? then
      # Probably we have http_proxy_* variables?
      uri.user = escape(ENV['http_proxy_user'] || ENV['HTTP_PROXY_USER'])
      uri.password = escape(ENV['http_proxy_pass'] || ENV['HTTP_PROXY_PASS'])
    end

    uri
  end

  ##
  # Normalize the URI by adding "http://" if it is missing.

  def normalize_uri(uri)
    (uri =~ /^(https?|ftp|file):/) ? uri : "http://#{uri}"
  end

  def escape(str)
    return unless str
    @uri_parser ||= uri_escaper
    @uri_parser.escape str
  end

  def uri_escaper
    URI::Parser.new
  rescue NameError
    URI
  end

end
