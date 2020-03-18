# frozen_string_literal: true

require "json"

require "parallel_tests/rspec/runner"

module TurboTests
  class Runner
    def self.run(opts = {})
      files = opts[:files]
      formatters = opts[:formatters]
      tags = opts[:tags]
      start_time = opts.fetch(:start_time) { Time.now }
      fail_fast = opts.fetch(:fail_fast, nil)

      reporter = Reporter.from_config(formatters, start_time)

      new(
        :reporter => reporter,
        :files => files,
        :tags => tags,
        :fail_fast => fail_fast
      ).run
    end

    def initialize(opts)
      @reporter = opts[:reporter]
      @files = opts[:files]
      @tags = opts[:tags]
      @fail_fast = opts[:fail_fast]
      @failure_count = 0
      @runtime_log = "tmp/parallel_runtime_rspec.log"

      @messages = Thread::Queue.new
      @threads = []
    end

    def run
      @num_processes = ParallelTests.determine_number_of_processes(nil)

      tests_in_groups =
        ParallelTests::RSpec::Runner.tests_in_groups(
          @files,
          @num_processes,
          :runtime_log => @runtime_log
        )

      tests_in_groups.each_with_index do |tests, process_id|
        start_regular_subprocess(tests, process_id + 1)
      end

      handle_messages

      @reporter.finish

      @threads.each(&:join)

      @reporter.failed_examples.empty?
    end

    protected

    def start_regular_subprocess(tests, process_id)
      start_subprocess(
        { "TEST_ENV_NUMBER" => process_id.to_s },
        @tags.map {|tag| "--tag=#{tag}" },
        tests,
        process_id
      )
    end

    def start_subprocess(env, extra_args, tests, process_id)
      if tests.empty?
        @messages << {
          "type" => "exit",
          "process_id" => process_id,
        }
      else
        require "securerandom"
        env["RSPEC_FORMATTER_OUTPUT_ID"] = SecureRandom.uuid
        env["RUBYOPT"] = ["-I#{File.expand_path("..", __dir__)}", ENV["RUBYOPT"]].compact.join(" ")

        command_name = Gem.win_platform? ? [Gem.ruby, "bin/rspec"] : "bin/rspec"

        seed = rand(0xFFFF).to_s

        command = [
          *command_name,
          *extra_args,
          "--seed", seed,
          "--format", "ParallelTests::RSpec::RuntimeLogger",
          "--out", @runtime_log,
          "--format", "TurboTests::JsonRowsFormatter",
          *tests
        ]

        rerun_command = [
          *command_name,
          *extra_args,
          "--seed", seed,
          *tests
        ]

        puts "TEST_ENV_NUMBER=#{env["TEST_ENV_NUMBER"]} #{rerun_command.join(" ")}"

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

    def start_copy_thread(src, dst)
      Thread.new do
        loop do
          msg = src.readpartial(4096)
        rescue EOFError
          break
        else
          dst.write(msg)
        end
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

    def fail_fast_met
      !@fail_fast.nil? && @fail_fast >= @failure_count
    end
  end
end
