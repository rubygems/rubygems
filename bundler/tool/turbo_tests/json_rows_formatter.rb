# frozen_string_literal: true

require "json"
require "rspec/core"
require "rspec/core/formatters"
require "rspec/core/notifications"

module RSpecExt
  def handle_interrupt
    if RSpec.world.wants_to_quit
      exit!(1)
    else
      RSpec.world.wants_to_quit = true
    end
  end
end

RSpec::Core::Runner.singleton_class.prepend(RSpecExt)

module TurboTests
  # An RSpec formatter used for each subprocess during parallel test execution
  class JsonRowsFormatter
    RSpec::Core::Formatters.register(
      self,
      :message,
      :close,
      :example_failed,
      :example_passed,
      :example_pending,
    )

    attr_reader :output

    def initialize(output)
      @output = output
    end

    def example_passed(notification)
      output_row(
        "type" => :example_passed,
        "example" => example_to_json(notification.example)
      )
    end

    def example_pending(notification)
      output_row(
        "type" => :example_pending,
        "example" => example_to_json(notification.example)
      )
    end

    def example_failed(notification)
      output_row(
        "type" => :example_failed,
        "example" => example_to_json(notification.example)
      )
    end

    def message(notification)
      output_row(
        "type" => :message,
        "message" => notification.message
      )
    end

    def close(notification)
      output_row(
        "type" => :close,
      )
    end

  private

    def exception_to_json(exception)
      if exception
        {
          "class_name" => exception.class.name.to_s,
          "backtrace" => exception.backtrace,
          "message" => exception.message,
          "cause" => exception_to_json(exception.cause),
        }
      end
    end

    def execution_result_to_json(result)
      {
        "example_skipped?" => result.example_skipped?,
        "pending_message" => result.pending_message,
        "status" => result.status,
        "pending_fixed?" => result.pending_fixed?,
        "exception" => exception_to_json(result.exception),
      }
    end

    def stack_frame_to_json(frame)
      {
        "shared_group_name" => frame.shared_group_name,
        "inclusion_location" => frame.inclusion_location,
      }
    end

    def example_to_json(example)
      {
        "execution_result" => execution_result_to_json(example.execution_result),
        "location" => example.location,
        "full_description" => example.full_description,
        "metadata" => {
          "shared_group_inclusion_backtrace" =>
            example.metadata[:shared_group_inclusion_backtrace].map {|frame| stack_frame_to_json(frame) },
        },
        "location_rerun_argument" => example.location_rerun_argument,
      }
    end

    def output_row(obj)
      output.puts ENV["RSPEC_FORMATTER_OUTPUT_ID"] + obj.to_json
    end
  end
end
