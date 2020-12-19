# frozen_string_literal: true

module Bundler
  module GemHelpers
    GENERIC_CACHE = { Gem::Platform::RUBY => Gem::Platform::RUBY } # rubocop:disable Style/MutableConstant
    GENERICS = [
      [Gem::Platform.new("java"), Gem::Platform.new("java")],
      [Gem::Platform.new("mswin32"), Gem::Platform.new("mswin32")],
      [Gem::Platform.new("mswin64"), Gem::Platform.new("mswin64")],
      [Gem::Platform.new("universal-mingw32"), Gem::Platform.new("universal-mingw32")],
      [Gem::Platform.new("x64-mingw32"), Gem::Platform.new("x64-mingw32")],
      [Gem::Platform.new("x86_64-mingw32"), Gem::Platform.new("x64-mingw32")],
      [Gem::Platform.new("mingw32"), Gem::Platform.new("x86-mingw32")],
    ].freeze

    def generic(p)
      GENERIC_CACHE[p] ||= begin
        _, found = GENERICS.find do |match, _generic|
          p.os == match.os && (!match.cpu || p.cpu == match.cpu)
        end
        found || Gem::Platform::RUBY
      end
    end
    module_function :generic

    def generic_local_platform
      generic(local_platform)
    end
    module_function :generic_local_platform

    def local_platform
      Bundler.local_platform
    end
    module_function :local_platform

    def platform_specificity_match(spec_platform, user_platform)
      spec_platform = Gem::Platform.new(spec_platform)

      PlatformMatch.specificity_score(spec_platform, user_platform)
    end
    module_function :platform_specificity_match

    def select_best_platform_match(specs, platform)
      specs.select {|spec| spec.match_platform(platform) }.
        min_by {|spec| platform_specificity_match(spec.platform, platform) }
    end
    module_function :select_best_platform_match

    class PlatformMatch
      def self.specificity_score(spec_platform, user_platform)
        return -1 if spec_platform == user_platform
        return 1_000_000 if spec_platform.nil? || spec_platform == Gem::Platform::RUBY || user_platform == Gem::Platform::RUBY

        os_match(spec_platform, user_platform) +
          cpu_match(spec_platform, user_platform) * 10 +
          platform_version_match(spec_platform, user_platform) * 100
      end

      def self.os_match(spec_platform, user_platform)
        if spec_platform.os == user_platform.os
          0
        else
          1
        end
      end

      def self.cpu_match(spec_platform, user_platform)
        if spec_platform.cpu == user_platform.cpu
          0
        elsif spec_platform.cpu == "arm" && user_platform.cpu.to_s.start_with?("arm")
          0
        elsif spec_platform.cpu.nil? || spec_platform.cpu == "universal"
          1
        else
          2
        end
      end

      def self.platform_version_match(spec_platform, user_platform)
        if spec_platform.version == user_platform.version
          0
        elsif spec_platform.version.nil?
          1
        else
          2
        end
      end
    end
  end
end
