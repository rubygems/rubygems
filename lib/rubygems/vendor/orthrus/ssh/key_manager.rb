require 'rubygems/vendor/orthrus/ssh'
require 'rubygems/vendor/orthrus/ssh/agent'

module Gem::Orthrus::SSH
  class KeyManager
    def initialize(try_agent=true)
      @keys = []

      agent = nil
      if try_agent and Agent.available?
        begin
          agent = Agent.connect
        rescue IOError
          # ignore
        end
      end

      @agent = agent
    end

    attr_reader :keys

    def add_key(key)
      @keys << key
    end

    def load_key(path)
      add_key Orthrus::SSH.load_private(path)
    end

    def agent_identities
      @agent && @agent.identities
    end

    def each_key
      @keys.each { |x| yield x }
      if @agent
        @agent.identities.each do |x|
          x.source = @agent
          yield x
        end
      end
    end

    def sign(key, data, b64armor=false)
      if key.source.kind_of? Agent
        _, sign = key.source.sign key, data
      else
        sign = key.sign data
      end

      if b64armor
        Utils.encode64 sign
      else
        sign
      end
    end
  end
end
