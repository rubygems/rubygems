# frozen_string_literal: true

module TurboTests
  class Runner
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
          "--require", File.expand_path("windows_json_rows_formatter", __dir__),
          "--format", "TurboTests::WindowsJsonRowsFormatter",
          *tests
        ]

        if @verbose
          command_str = [
            env.map {|k, v| "#{k}=#{v}" }.join(" "),
            command.join(" "),
          ].select {|x| x.size > 0 }.join(" ")

          warn "Process #{process_id}: #{command_str}"
        end

        stdin, stdout, stderr, wait_thr = Open3.popen3(env, *command)
        stdin.close

        @threads <<
          Thread.new do
            require "json"
            stdout.each_line do |line|
              result = line.split(env["RSPEC_FORMATTER_OUTPUT_ID"])

              output = result.shift
              print(output) unless output.empty?

              message = result.shift
              next unless message

              message = JSON.parse(message, symbolize_names: true)
              message[:process_id] = process_id
              @messages << message
            end

            @messages << { type: "exit", process_id: process_id }
          end

        @threads << start_copy_thread(stderr, STDERR)

        @threads << Thread.new do
          unless wait_thr.value.success?
            @messages << { type: "error" }
          end
        end

        wait_thr
      end
    end
  end
end
