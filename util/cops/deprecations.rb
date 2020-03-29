# frozen_string_literal: true

module RuboCop
  module Cop
    module Rubygems
      # This cop enforces that no outdated deprecations are present on RubyGems
      # code base.
      #
      # @example
      #
      #   As of March, 2020
      #
      #   # bad
      #   deprecate :safdfa, :none
      #
      #   # good
      #   deprecate :safdfa
      #   deprecate :safdfa, safdfa_replacement,
      #
      class Deprecations < Cop

        MSG = "Remove `deprecate` calls for the next major release " \

        def on_send(node)
          _receiver, method_name, *args = *node
          return unless method_name == :deprecate

          add_offense(node)
        end

        private

        def message(node)
          format(MSG, method: node.method_name)
        end

      end
    end
  end
end
