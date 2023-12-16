# frozen_string_literal: true

module Bundler
  module UI
    class JsonShell < UI::Shell
      def table(header, rows, options = {})
        return unless info?
        empty_row = header.keys.to_h {|k| [k, nil] }
        data = rows.map {|row| empty_row.merge(row) }

        require "json"
        json_text = options[:pretty] ? JSON.pretty_generate(data) : JSON.generate(data)
        tell_me json_text
      end

      # -- override info/config/debug to write to stderr instead of stdout --

      def info(msg = nil, newline = nil)
        return unless info?
        tell_err(msg || yield, nil, newline)
      end

      def confirm(msg = nil, newline = nil)
        return unless confirm?
        tell_err(msg || yield, :green, newline)
      end

      def debug(msg = nil, newline = nil)
        return unless debug?
        tell_err(msg || yield, nil, newline)
      end
    end
  end
end
