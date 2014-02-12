require 'thread'

module Gem
  class Request
    class ConnectionPools # :nodoc:
      @client = Net::HTTP
      class << self; attr_accessor :client; end

      def initialize proxy_uri, cert_files
        @proxy_uri  = proxy_uri
        @cert_files = cert_files
        @pools      = {}
        @pool_mutex = Mutex.new
      end

      def pool_for uri
        http_args = net_http_args(uri, @proxy_uri)
        key       = http_args + [https?(uri)]
        @pool_mutex.synchronize do
          @pools[key] ||= if https?(uri)
                            HTTPSPool.new(http_args, @cert_files, @proxy_uri)
                          else
                            HTTPPool.new(http_args, @cert_files, @proxy_uri)
                          end
        end
      end

      ###
      # A connection "pool" that only manages one connection for now.
      # Provides thread safe `checkout` and `checkin` methods.  The
      # pool consists of one connection that corresponds to `http_args`.
      # This class is private, do not use it.
      class HTTPPool # :nodoc:
        attr_reader :cert_files, :proxy_uri

        def initialize http_args, cert_files, proxy_uri
          @http_args  = http_args
          @cert_files = cert_files
          @proxy_uri  = proxy_uri
          @queue      = SizedQueue.new 1
          @queue << nil
        end

        def checkout
          @queue.pop || make_connection
        end

        def checkin connection
          @queue.push connection
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
          net_http_args + [nil, nil]
        end
      end
    end
  end
end
