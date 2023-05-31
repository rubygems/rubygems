# frozen_string_literal: true

module RuboCop
  module Cop
    module Rubygems
      # This cop enforces that no outdated deprecations are present on RubyGems
      # code base.
      #
      # @example
      #
      #   # bad
      #   rubygems_deprecate :safdfa, :none
      #
      #   # good
      #   # the `deprecate` call is fully removed
      #
      class Deprecations < Cop
        def on_send(node)
          _receiver, method_name, *args = *node
          return unless method_name == :rubygems_deprecate || method_name == :rubygems_deprecate_command

          add_offense(node)
        end

        private

        def message(node)
          msg = "Remove `#{node.method_name}` calls for the next major release "
          format(msg, method: node.method_name)
        end
      end
    end
  end
end
