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
        RESTRICT_ON_SEND = [:rubygems_deprecate, :rubygems_deprecate_command].freeze

        def on_send(node)
          if node.method_name == :rubygems_deprecate && node.arguments.size >= 3
            version_arg = node.arguments[2]
            if version_arg&.str_type?
              target_version = version_arg.str_content
              return if current_version < Gem::Version.new(target_version)
            end
          end

          add_offense(node, message: format(MSG, method_name: node.method_name))
        end

        private

        def current_version
          @current_version ||= Gem::Version.new(Gem::VERSION)
        end
      end
    end
  end
end
