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
        MSG = "Remove `%<method_name>s` calls whose deprecation horizon has been reached."
        RESTRICT_ON_SEND = [:rubygems_deprecate, :rubygems_deprecate_command].freeze

        def on_send(node)
          return unless expired?(horizon_of(node))

          add_offense(node, message: format(MSG, method_name: node.method_name))
        end

        private

        # Prereleases compare lower than their final version, so the release
        # segments alone are used to make 4.1.0.beta1 expire a "4.1" horizon.
        def current_version
          @current_version ||= Gem::Version.new(Gem::VERSION).release
        end

        def expired?(horizon)
          horizon ? current_version >= horizon : major_release?
        end

        def horizon_of(node)
          version_arg = node.method_name == :rubygems_deprecate ? node.arguments[2] : node.arguments[0]
          Gem::Version.new(version_arg.str_content) if version_arg&.str_type?
        end

        def major_release?
          current_version.segments[1..].all?(&:zero?)
        end
      end
    end
  end
end
