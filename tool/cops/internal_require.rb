# frozen_string_literal: true

module RuboCop
  module Cop
    module Rubygems
      # This cop enforces that Bundler code loads its own files with
      # `require_relative`, which keeps loading independent of the load path.
      #
      # @example
      #
      #   # bad
      #   require "bundler/settings"
      #
      #   # good
      #   require_relative "settings"
      #
      class InternalRequire < Base
        MSG = "Use `require_relative` instead of `require` to load internal files."
        RESTRICT_ON_SEND = [:require].freeze

        def on_send(node)
          return unless node.receiver.nil?

          path = node.first_argument
          return unless path&.str_type?
          return unless path.str_content == "bundler" || path.str_content.start_with?("bundler/")

          add_offense(node)
        end
      end
    end
  end
end
