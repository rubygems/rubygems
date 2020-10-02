# frozen_string_literal: true

module RuboCop
  module Cop
    module Rubygems
      # This cop enforces that no outdated deprecations are present on RubyGems
      # code base.
      #
      # @example
      #
      #   As of March, 2019
      #
      #   # bad
      #   deprecate :safdfa, nil, 2018, 12
      #   deprecate :safdfa, nil, 2019, 03
      #
      #   # good
      #   deprecate :safdfa, nil, 2019, 04
      #
      class Deprecations < Cop

        MSG = "Remove `deprecate` calls with dates in the past, along with " \
          "the methods they deprecate, or expand the deprecation horizons to " \
          "a future date"

        def on_send(node)
          _receiver, method_name, *args = *node
          return unless method_name == :deprecate

          scheduled_year = args[2].children.last
          scheduled_month = args[3].children.last

          current_time = Time.now

          current_year = current_time.year
          current_month = current_time.month

          if current_year >= scheduled_year || (current_year == scheduled_year && current_month >= scheduled_month)
            add_offense(node)
          end
        end

        private

        def message(node)
          format(MSG, method: node.method_name)
        end

      end
    end
  end
end
