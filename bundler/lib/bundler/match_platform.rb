# frozen_string_literal: true

require_relative "gem_helpers"

module Bundler
  module MatchPlatform
    include GemHelpers

    def match_platform(p)
      MatchPlatform.platforms_match?(platform, p)
    end

    def self.platforms_match?(gemspec_platform, local_platform)
      # p({ gem: gemspec_platform, local: local_platform })
      return true if gemspec_platform.nil?
      return true if gemspec_platform == Gem::Platform::RUBY
      return true if gemspec_platform == local_platform
      gemspec_platform = Gem::Platform.new(gemspec_platform)
      #return true if GemHelpers.generic(gemspec_platform) === local_platform
      # ^=> Bundler::GemHelpers.generic(Gem::Platform.new('x86_64-linux-musl'))
      #  => ruby
      #     == local_platform (from resolver's spec_group_ruby)
      #  => linux-musl appears for linux through ruby!!!
      return true if gemspec_platform === local_platform

      false
    end
  end
end
