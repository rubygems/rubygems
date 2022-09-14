# frozen_string_literal: true

module Bundler
  class Resolver
    class Package
      attr_reader :name, :platforms

      def initialize(name, platforms, locked_specs, prerelease_specified: false, force_ruby_platform: false)
        @name = name
        @platforms = platforms
        @locked_specs = locked_specs
        @prerelease_specified = prerelease_specified
        @force_ruby_platform = force_ruby_platform
      end

      def ==(other)
        @name == other.name
      end

      def hash
        @name.hash
      end

      def locked_version
        @locked_specs[name].first&.version
      end

      def prerelease_specified?
        @prerelease_specified
      end

      def force_ruby_platform?
        @force_ruby_platform
      end
    end
  end
end
