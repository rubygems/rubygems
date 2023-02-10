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
      class Deprecations < Base
        MSG = "Remove `%<method_name>s` calls for the next major release."
        RESTRICT_ON_SEND = %i[rubygems_deprecate rubygems_deprecate_command].freeze

        def on_send(node)
          add_offense(node, message: format(MSG, method_name: node.method_name))
        end
      end
    end
  end
end
