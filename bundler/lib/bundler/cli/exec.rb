# frozen_string_literal: true

require_relative "../current_ruby"

module Bundler
  class CLI::Exec
    attr_reader :options, :args, :cmd

    TRAPPED_SIGNALS = %w[INT].freeze

    def initialize(options, args)
      @options = options
      @cmd = args.shift
      @args = args
      @args << { close_others: !options.keep_file_descriptors? } unless Bundler.current_ruby.jruby?
    end

    def run
      validate_cmd!
      SharedHelpers.set_bundle_environment
      if (bin_path = Bundler.which(cmd))
        if !Bundler.settings[:disable_exec_load] and has_shebang?(bin_path)
          begin
            if Gem.win_platform? # remove `bat` suffix
              bin_path = File.join(File.dirname(bin_path), File.basename(bin_path, File.extname(bin_path)))
            end
            kernel_load(bin_path, *args)
          rescue LoadError
            kernel_exec(bin_path, *args)
          end
        else
          kernel_exec(bin_path, *args)
        end
      else
        # exec using the given command
        kernel_exec(cmd, *args)
      end
    end

    private

    def validate_cmd!
      return unless cmd.nil?
      Bundler.ui.error "bundler: exec needs a command to run"
      exit 128
    end

    def kernel_exec(*args)
      Kernel.exec(*args)
    rescue Errno::EACCES, Errno::ENOEXEC
      Bundler.ui.error "bundler: not executable: #{cmd}"
      exit 126
    rescue Errno::ENOENT
      Bundler.ui.error "bundler: command not found: #{cmd}"
      Bundler.ui.warn "Install missing gem executables with `bundle install`"
      exit 127
    end

    def kernel_load(file, *args)
      args.pop if args.last.is_a?(Hash)
      ARGV.replace(args)
      $0 = file
      Process.setproctitle(process_title(file, args)) if Process.respond_to?(:setproctitle)
      require_relative "../setup"
      TRAPPED_SIGNALS.each {|s| trap(s, "DEFAULT") }
      Kernel.load(file)
    rescue SystemExit, SignalException
      raise
    rescue Exception # rubocop:disable Lint/RescueException
      Bundler.ui.error "bundler: failed to load command: #{cmd} (#{file})"
      Bundler::FriendlyErrors.disable!
      raise
    end

    def process_title(file, args)
      "#{file} #{args.join(" ")}".strip
    end

    def has_shebang?(file)
      if File.zero?(file)
        Bundler.ui.warn "#{file} is empty"
        return false
      end

      first_line = File.open(file, "rb") {|f| f.read(5) }
      return first_line.start_with?("@ECHO") if Gem.win_platform?
      return first_line.start_with?("#!")
    end
  end
end
