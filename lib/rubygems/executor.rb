# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rubygems/platform'

module Gem
  module Web
    class Executor

      def supported_options_from_metadata
        ["source_code_uri", "documentation_uri"]
      end

      def open_page(gem, options)
        spec = Gem::Specification.find_by_name(gem)

        if options[:sourcecode]
          get_info_from_metadata(spec, "source_code_uri")
        elsif options[:doc]
          get_info_from_metadata(spec, "documentation_uri")
        elsif options[:webpage]
          open_default_browser(spec.homepage)
        elsif options[:rubygems]
          open_rubygems(gem)
        else # The default option is homepage
          open_default_browser(spec.homepage)
        end
      rescue Gem::MissingSpecError => e
        puts e.message
      end

      def get_info_from_metadata(spec, info)
        return unless supported_options_from_metadata.include?(info)

        uri = spec.metadata[info]
        if !uri.nil? && !uri.empty?
          open_default_browser(uri)
        else
          puts("This gem does not have this information.")
        end
      end

      def open_rubygems(gem)
        open_default_browser("https://rubygems.org/gems/#{gem}")
      end

      def open_default_browser(uri)
        open_browser_cmd = ENV['BROWSER']
        if open_browser_cmd.nil? || open_browser_cmd.empty?
          puts uri
        else
          system(open_browser_cmd, uri)
        end
      end

    end
  end
end
