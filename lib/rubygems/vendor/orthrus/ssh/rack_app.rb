require 'rubygems/vendor/orthrus/ssh'
require 'rack'

module Gem::Orthrus::SSH
  class RackApp
    def initialize(sessions)
      @sessions = sessions
    end

    attr_reader :sessions

    def call(env)
      req = Rack::Request.new(env)

      case req.params['state']
      when 'find'
        find req
      when 'signed'
        verify req
      else
        [500, {}, ["unknown state"]]
      end
    end

    def form(body)
      [200,
       { "Content-Type" => "application/x-www-form-urlencoded" },
       [Rack::Utils.build_query(body)]
      ]
    end

    def find(req)
      user = req.params['user']
      id = req.params["id"]

      unless pub = @sessions.find_key(user, id)
        return form :code => "unknown"
      end

      session, nonce = @sessions.new_session(user, pub)

      nonce = Utils.sha1_hash(nonce)

      form :code => 'check', :session_id => session, :nonce => nonce
    end

    def verify(req)
      id = req.params["session_id"].to_i
      nonce, pub = @sessions.find_session(id)

      nonce = Utils.sha1_hash(nonce)

      sig = req.params['sig']

      token = @sessions.new_access_token(id)

      if pub.verify(sig, nonce, true)
        form :code => 'verified', :access_token => token
      else
        form :code => "fail"
      end
    end
  end
end
