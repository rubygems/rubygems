# frozen_string_literal: true

module Bundler
  # Lightweight IO tracing for bundler, controlled by BUNDLER_IO_TRACE=1.
  # Logs every significant IO operation (file read, write, HTTP request,
  # directory scan) with timestamps and durations to stderr.
  #
  # Usage: BUNDLER_IO_TRACE=1 bundle install
  module IOTrace
    ENABLED = ENV["BUNDLER_IO_TRACE"] == "1"
    START_TIME = Process.clock_gettime(Process::CLOCK_MONOTONIC) if ENABLED

    @mutex = Thread::Mutex.new if ENABLED

    class << self
      def enabled?
        ENABLED
      end

      # Log an IO operation with timing. Yields the block and measures duration.
      # category: :file_read, :file_write, :file_stat, :dir_scan, :http, :file_copy, :file_link
      def trace(category, description, &block)
        return yield unless ENABLED

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        elapsed = start - START_TIME

        @mutex.synchronize do
          $stderr.puts format(
            "[IO_TRACE] %8.3fs +%7.3fms  %-12s %s",
            elapsed, duration * 1000, category, description
          )
        end

        result
      end

      # Log without timing (for noting an operation that was skipped/cached)
      def note(category, description)
        return unless ENABLED

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - START_TIME
        @mutex.synchronize do
          $stderr.puts format(
            "[IO_TRACE] %8.3fs  (cached)    %-12s %s",
            elapsed, category, description
          )
        end
      end
    end
  end
end
