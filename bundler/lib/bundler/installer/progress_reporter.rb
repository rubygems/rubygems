# frozen_string_literal: true

module Bundler
  class ParallelInstaller
    # A live-updating terminal progress reporter for parallel gem operations.
    # Inspired by uv's compact phase summaries.
    #
    # TTY output (single line redrawn in place per phase):
    #
    #   ◐ Fetching gems  ( 42/382) 3.2s
    #     ↳ nokogiri 1.16.0 - compiling native extensions (12.3s)
    #   ✓ Fetched 382 gems in 4.1s
    #   ✓ Extracted 382 gems in 0.8s
    #   ◐ Installing gems (280/382) 2.1s
    #     ↳ nokogiri 1.16.0 - compiling native extensions (8.4s)
    #   ✓ Installed 382 gems in 12.3s
    #
    # Non-TTY falls back to phase summaries only.
    class ProgressReporter
      SPINNERS = %w[◐ ◓ ◑ ◒].freeze
      CHECK    = "\u2713" # ✓

      RESET  = "\e[0m"
      BOLD   = "\e[1m"
      DIM    = "\e[2m"
      GREEN  = "\e[32m"
      CYAN   = "\e[36m"
      WHITE  = "\e[37m"
      CLR    = "\e[2K"   # clear entire line

      attr_reader :tty

      def initialize
        @tty = $stderr.tty?
        @mutex = Mutex.new
        @completed_count = 0
        @total_count = 0
        @phase = nil
        @phase_start = nil
        @spinner_tick = 0
        @slow_item = nil       # {name:, version:, detail:, started_at:}
        @has_slow_line = false  # whether we printed a second line for slow item
        @total_width = 1       # digit width for right-aligning counts
      end

      # --- Phase lifecycle ---

      def start_phase(phase_name, total)
        @mutex.synchronize do
          @phase = phase_name
          @total_count = total
          @completed_count = 0
          @phase_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @slow_item = nil
          @has_slow_line = false
          @total_width = total.to_s.length

          write_header if @tty
        end
      end

      def finish_phase
        @mutex.synchronize do
          elapsed = elapsed_since(@phase_start)

          if @tty
            # Clear slow item line if present
            if @has_slow_line
              $stderr.write "\n#{CLR}\e[A"  # go to slow line, clear it, back up
              @has_slow_line = false
            end
            # Overwrite the spinner line with the final summary
            $stderr.write "\r#{CLR}"
          end

          summary = "#{GREEN}#{CHECK}#{RESET} " \
                    "#{phase_past_tense} " \
                    "#{BOLD}#{@completed_count}#{RESET} " \
                    "#{@completed_count == 1 ? "gem" : "gems"} " \
                    "#{DIM}in #{format_time(elapsed)}#{RESET}"
          $stderr.puts summary
          $stderr.flush

          @slow_item = nil
          @phase = nil
        end
      end

      # --- Item tracking ---

      def item_start(name, version, detail = nil)
        @mutex.synchronize do
          # Track items that might be slow (native ext compilation, git checkouts)
          if detail&.include?("compil") || detail&.include?("git")
            @slow_item = {
              name: name,
              version: version.to_s,
              detail: detail,
              started_at: Process.clock_gettime(Process::CLOCK_MONOTONIC),
            }
          end
        end
      end

      def item_done(name, detail = nil)
        @mutex.synchronize do
          @completed_count += 1
          @slow_item = nil if @slow_item && @slow_item[:name] == name
          write_header if @tty
        end
      end

      def item_skip(name, version = nil)
        @mutex.synchronize do
          @completed_count += 1
        end
      end

      # --- Timer tick (called from spinner thread) ---

      def tick
        @mutex.synchronize do
          @spinner_tick += 1
          write_header if @tty
        end
      end

      private

      def write_header
        return unless @phase

        elapsed = elapsed_since(@phase_start)
        spinner = "#{CYAN}#{SPINNERS[@spinner_tick % SPINNERS.size]}#{RESET}"
        count = format("%#{@total_width}d", @completed_count)

        # Main progress line (rewritten in place)
        line = "#{spinner} #{BOLD}#{phase_label}#{RESET} " \
               "#{DIM}(#{count}/#{@total_count})#{RESET} " \
               "#{DIM}#{format_time(elapsed)}#{RESET}"

        $stderr.write "\r#{CLR}#{line}"

        # Show slow item on a second line if it's been > 3s
        if @slow_item
          item_elapsed = elapsed_since(@slow_item[:started_at])
          if item_elapsed > 3.0
            slow_line = "    #{DIM}\u21b3 #{@slow_item[:name]} #{@slow_item[:version]} " \
                        "- #{@slow_item[:detail]} (#{format_time(item_elapsed)})#{RESET}"
            if @has_slow_line
              # Overwrite existing slow line
              $stderr.write "\n\r#{CLR}#{slow_line}\e[A"
            else
              # Print new slow line, then move cursor back up
              $stderr.write "\n#{CLR}#{slow_line}\e[A"
              @has_slow_line = true
            end
          end
        elsif @has_slow_line
          # Slow item finished, clear its line
          $stderr.write "\n\r#{CLR}\e[A"
          @has_slow_line = false
        end

        $stderr.flush
      end

      def phase_label
        case @phase
        when :download then "Fetching gems "
        when :extract  then "Extracting gems"
        when :install  then "Installing gems"
        else @phase.to_s
        end
      end

      def phase_past_tense
        case @phase
        when :download then "Fetched"
        when :extract  then "Extracted"
        when :install  then "Installed"
        else @phase.to_s
        end
      end

      def elapsed_since(start)
        return 0.0 unless start
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      end

      def format_time(seconds)
        if seconds < 60
          format("%.1fs", seconds)
        else
          mins = (seconds / 60).to_i
          secs = seconds - (mins * 60)
          format("%dm%.1fs", mins, secs)
        end
      end
    end
  end
end
