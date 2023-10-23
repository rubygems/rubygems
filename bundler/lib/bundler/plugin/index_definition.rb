# frozen_string_literal: true

module Bundler
  module Plugin
    # duck-type of Definition for feeding to LockfileGenerator
    IndexDefinition = Struct.new(:sources, :specs, :dependencies) do
      def platforms
        [Bundler.local_platform]
      end

      def locked_ruby_version; end

      def bundler_version_to_lock
        VERSION
      end

      alias_method :resolve, :specs
    end
  end
end
