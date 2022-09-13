# frozen_string_literal: true

module Bundler
  class Resolver
    class Package
      attr_reader :name, :platforms

      def initialize(name, platforms, prerelease_specified: false, force_ruby_platform: false)
        @name = name
        @platforms = platforms
        @prerelease_specified = prerelease_specified
        @force_ruby_platform = force_ruby_platform
      end

      def ==(other)
        @name == other.name
      end

      def hash
        @name.hash
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
