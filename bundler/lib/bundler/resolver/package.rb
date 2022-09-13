# frozen_string_literal: true

module Bundler
  class Resolver
    class Package
      attr_reader :name, :platforms

      def initialize(name, platforms, prerelease_specified: false)
        @name = name
        @platforms = platforms
        @prerelease_specified = prerelease_specified
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
    end
  end
end
