# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rubygems/platform'

module Gem
  module Web
    class Executor

      def open_page(gem, options)
        spec = Gem::Specification.find_by_name(gem)

        if options[:sourcecode]
          source_code_uri = spec.metadata["source_code_uri"]
          if source_code_uri
            open_default_browser(source_code_uri)
          else
            puts("This gem has no info about its source code.")
          end
        elsif options[:doc]
          documentation_uri = spec.metadata["documentation_uri"]
          if documentation_uri
            open_default_browser(documentation_uri)
          else
            puts("This gem has no info about its documentation.")
          end
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
