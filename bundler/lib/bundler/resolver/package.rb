# frozen_string_literal: true

module Bundler
  class Resolver
    class Package
      attr_reader :name

      def initialize(name, prerelease_specified: false)
        @name = name
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
