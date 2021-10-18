# frozen_string_literal: true

require_relative "command_execution"

module Spec
  module Subprocess
    def command_executions
      @command_executions ||= []
    end

    def last_command
      command_executions.last || raise("There is no last command")
    end

    def out
      last_command.stdout
    end

    def err
      last_command.stderr
    end

    def exitstatus
      last_command.exitstatus
    end

    def git(cmd, path = Dir.pwd, options = {})
      sh("git #{cmd}", options.merge(:dir => path))
    end

    def sh(cmd, options = {})
      dir = options[:dir]
      env = options[:env] || {}

      command_execution = CommandExecution.new(cmd.to_s, dir)

      require "open3"
      require "shellwords"
      Open3.popen3(env, *cmd.shellsplit, :chdir => dir) do |stdin, stdout, stderr, wait_thr|
        yield stdin, stdout, wait_thr if block_given?
        stdin.close

        stdout_read_thread = Thread.new { stdout.read }
        stderr_read_thread = Thread.new { stderr.read }
        command_execution.stdout = stdout_read_thread.value.strip
        command_execution.stderr = stderr_read_thread.value.strip

        status = wait_thr.value
        command_execution.exitstatus = if status.exited?
          status.exitstatus
        elsif status.signaled?
          128 + status.termsig
        end
      end

      unless options[:raise_on_error] == false || command_execution.success?
        raise <<~ERROR

          Invoking `#{cmd}` failed with output:
          ----------------------------------------------------------------------
          #{command_execution.stdboth}
          ----------------------------------------------------------------------
        ERROR
      end

      command_executions << command_execution

      command_execution.stdout
    end

    def all_commands_output
      return "" if command_executions.empty?

      "\n\nCommands:\n#{command_executions.map(&:to_s_verbose).join("\n\n")}"
    end
  end
end
