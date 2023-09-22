# frozen_string_literal: true

require "turbo_tests/json_rows_formatter"

module TurboTests
  class WindowsJsonRowsFormatter < JsonRowsFormatter
    RSpec::Core::Formatters.register(
      self,
      :start,
      :close,
      :example_failed,
      :example_passed,
      :example_pending,
      :example_group_started,
      :example_group_finished,
      :message,
      :seed
    )

    private

    def output_row(obj)
      output.puts ENV["RSPEC_FORMATTER_OUTPUT_ID"] + obj.to_json
      output.flush
    end
  end
end
