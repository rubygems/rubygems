# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rubygems/platform'

module Gem
  module Web
    class Executor

      OPEN_BROWSER_CMDS = {
        aix: "defaultbrowser",
        cygwin: "cygstart",
        darwin: "open",
        macruby: "open", #TODO: check this
        freebsd: "xdg-open",
        # FIXME: What to do?
        # hpux: "",
        # java: "",
        # dalvik: "",
        # dotnet: "",
        # linux: "xdg-open",
        mingw32: "start",
        netbsdelf: "xdg-open",
        openbsd: "xdg-open",
        bitrig: "xdg-open", # check this
        # solaris: "sdtwebclient", # version < 11
        # solaris: "xdg-open", # version > 11
        unknown: ""
      }.freeze

      attr_reader :open_browser_cmd

      def initialize
        local_os = Gem::Platform.local.os.to_sym
        @open_browser_cmd = OPEN_BROWSER_CMDS[local_os]
      end

      def open_page(gem, options)
        if options[:sourcecode]
          find_page(gem, "source_code_uri")
        elsif options[:doc]
          find_page(gem, "documentation_uri")
        elsif options[:webpage]
          find_page(gem, "homepage_uri")
        elsif options[:rubygems]
          open_rubygems(gem)
        elsif options[:rubytoolbox]
          open_rubytoolbox(gem)
        else
          find_github(gem)
        end
      end

      def find_page(gem, page)
        meta = get_api_metadata(gem)
        launch_browser(gem, meta[page]) unless meta.nil?
      end

      def find_github(gem)
        unless (meta = get_api_metadata(gem)).nil?
          links = [meta["source_code_uri"], meta["documentation_uri"], meta["homepage_uri"]]
          uri = links.find do |link|
            !link.nil? && link.match(/http(s?):\/\/(www\.)?github.com\/.*/i)
          end
          launch_browser(gem, uri)
        end
      end

      def get_api_metadata(gem)
        begin
          JSON.parse(open("https://rubygems.org/api/v1/gems/#{gem}.json").read)
        rescue OpenURI::HTTPError
          puts "Did not find #{gem} on rubygems.org"
          nil
        end
      end

      def launch_browser(gem, uri)
        if uri.nil? || uri.empty?
          puts "Did not find page for #{gem}, opening RubyGems page instead."
          uri = "https://rubygems.org/gems/#{gem}"
        end

        open_default_browser(uri)
      end

      def open_rubygems(gem)
        open_default_browser("https://rubygems.org/gems/#{gem}")
      end

      def open_rubytoolbox(gem)
        open_default_browser("https://www.ruby-toolbox.com/projects/#{gem}")
      end

      def open_default_browser(uri)
        system(@open_browser_cmd, uri)
      end

    end
  end
end
