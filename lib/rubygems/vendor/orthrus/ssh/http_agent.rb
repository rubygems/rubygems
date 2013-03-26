require 'rubygems/vendor/orthrus/ssh'
require 'rubygems/vendor/orthrus/ssh/agent'

require 'uri'

require 'net/http'

module Gem::Orthrus::SSH
  class HTTPAgent
    def initialize(url, key_manager=nil)
      @url = url
      @key_manager ||= KeyManager.new
      @access_token = nil
    end

    attr_reader :access_token

    def load_key(key)
      @key_manager.load_key key
    end

    def check(user, k)
      id = Rack::Utils.escape(k.public_identity)
      user = Rack::Utils.escape(user)

      url = @url + "?state=find&user=#{user}&id=#{id}"
      response = Net::HTTP.get_response url
      params = Rack::Utils.parse_query response.body

      return nil unless params["code"] == "check"

      [params['session_id'], params['nonce']]
    end

    def negotiate(k, sid, sig)
      sig = Rack::Utils.escape sig

      url = @url + "?state=signed&sig=#{sig}&session_id=#{sid}"

      response = Net::HTTP.get_response url
      params = Rack::Utils.parse_query response.body

      if params['code'] == "verified"
        return params['access_token']
      end

      return nil
    end

    def start(user)
      @key_manager.each_key do |k|
        sid, data = check(user, k)
        next unless sid

        sig = @key_manager.sign k, data, true

        token = negotiate(k, sid, sig)
        if token
          @access_token = token
          return
        end
      end

      raise "Unable to find key to authenticate with"
    end
  end
end
