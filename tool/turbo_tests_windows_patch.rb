# frozen_string_literal: true

module TurboTests
  class JsonRowsFormatter
    private

    def output_row(obj)
      output.puts ENV["RSPEC_FORMATTER_OUTPUT_ID"] + obj.to_json
    end
  end

  class Runner
    def run
      @num_processes = ParallelTests.determine_number_of_processes(nil)

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(
          @files,
          @num_processes,
          :runtime_log => @runtime_log
        )

      subprocess_opts = {
        record_runtime: nil,
      }

      tests_in_groups.each_with_index do |tests, process_id|
        start_regular_subprocess(tests, process_id + 1, **subprocess_opts)
      end

      handle_messages

      @reporter.finish

      @threads.each(&:join)

      @reporter.failed_examples.empty?
    end

    private

    def start_subprocess(env, extra_args, tests, process_id, record_runtime:)
      if tests.empty?
        @messages << {
          type: "exit",
          process_id: process_id,
        }
      else
        require "securerandom"
        env["RSPEC_FORMATTER_OUTPUT_ID"] = SecureRandom.uuid
        env["RUBYOPT"] = ["-I#{File.expand_path("..", __dir__)}", ENV["RUBYOPT"]].compact.join(" ")

        command_name = Gem.win_platform? ? [Gem.ruby, "bin/rspec"] : "bin/rspec"

        command = [
          *command_name,
          *extra_args,
          "--seed", rand(0xFFFF).to_s,
          "--format", "ParallelTests::RSpec::RuntimeLogger",
          "--out", @runtime_log,
          "--format", "TurboTests::JsonRowsFormatter",
          *tests
        ]

        if @verbose
          command_str = [
            env.map {|k, v| "#{k}=#{v}" }.join(" "),
            command.join(" "),
          ].select {|x| x.size > 0 }.join(" ")

          warn "Process #{process_id}: #{command_str}"
        end

        _stdin, stdout, stderr, _wait_thr = Open3.popen3(env, *command)

        @threads <<
          Thread.new do
            require "json"
            stdout.each_line do |line|
              result = line.split(env["RSPEC_FORMATTER_OUTPUT_ID"])

              output = result.shift
              print(output) unless output.empty?

              message = result.shift
              next unless message

              message = JSON.parse(message)
              message["process_id"] = process_id
              @messages << message
            end

            @messages << { "type" => "exit", "process_id" => process_id }
          end

        @threads << start_copy_thread(stderr, STDERR)
      end
    end

    def handle_messages
      exited = 0

      loop do
        message = @messages.pop
        case message["type"]
        when "example_passed"
          example = FakeExample.from_obj(message["example"])
          @reporter.example_passed(example)
        when "example_pending"
          example = FakeExample.from_obj(message["example"])
          @reporter.example_pending(example)
        when "example_failed"
          example = FakeExample.from_obj(message["example"])
          example["full_description"] = "[TEST_ENV_NUMBER=#{message["process_id"]}] #{example["full_description"]}"
          @reporter.example_failed(example)
          @failure_count += 1
          if fail_fast_met
            @threads.each(&:kill)
            break
          end
        when "message"
          notification = RSpec::Core::Notifications::MessageNotification.new(message["message"])
          @reporter.message(notification)
        when "close"
        when "exit"
          exited += 1
          if exited == @num_processes
            break
          end
        else
          warn("Unhandled message in main process: #{message}")
        end
      end
    rescue Interrupt
    end
  end
end
