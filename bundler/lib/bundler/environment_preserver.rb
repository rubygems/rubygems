# frozen_string_literal: true

module Bundler
  module EnvironmentPreserver
    def self.env_to_hash(env)
      to_hash = env.to_hash
      return to_hash unless Gem.win_platform?

      to_hash.each_with_object({}) {|(k,v), a| a[k.upcase] = v }
    end

    ORIGINAL_ENV = env_to_hash(ENV)

    # @return [Hash] Environment present before Bundler was activated
    def original_env
      ORIGINAL_ENV.clone
    end
  end
end
