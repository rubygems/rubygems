# frozen_string_literal: true
require 'open-uri'
require 'json'

module Gem
  module Web
    class Executor

      def open_page(gem, options)
        begin
          spec = Gem::Specification.find_by_name(gem)
        rescue Gem::MissingSpecError => e
          spec = fetch_remote_spec(gem)

          if spec.nil?
            puts "Could not find '#{gem}' in rubygems.org."
            return
          end
        end

        if options[:sourcecode]
          get_info_from_metadata(spec, "source_code_uri")
        elsif options[:doc]
          get_info_from_metadata(spec, "documentation_uri")
        elsif options[:rubygems]
          open_rubygems(gem)
        else
          open_browser(spec.homepage)
        end
      end

      def fetch_remote_spec(gem)
        dep = Gem::Dependency.new(gem)
        found, _ = Gem::SpecFetcher.fetcher.spec_for_dependency(dep)
        spec_tuple = found.first

        spec_tuple.first unless spec_tuple.nil? || spec_tuple.empty?
      end

      def get_info_from_metadata(spec, info)
        uri = spec.metadata[info]&.strip

        if uri.nil? || uri.empty?
          puts "Gem '#{spec.name}' does not specify #{info}."
        else
          open_browser(uri)
        end
      end

      def open_rubygems(gem)
        open_browser("https://rubygems.org/gems/#{gem}")
      end

      def open_browser(uri)
        browser = ENV["BROWSER"]
        if browser.nil? || browser.empty?
          puts uri
        else
          system(browser, uri)
        end
      end

    end
  end
end
