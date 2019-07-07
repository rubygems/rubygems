# frozen_string_literal: true
require 'open-uri'
require 'json'
require 'rubygems/platform'

module Gem
  module Web
    class Executor

      def open_default_browser_cmd(local_os, version, uri)
        case local_os
        when 'aix'
          "defaultbrowser #{uri}"
        when 'cygwin'
          "cygstart #{uri}"
        when 'darwin'
          "open #{uri}"
        when 'macruby'
          "open #{uri}"
        when 'freebsd'
          "xdg-open #{uri}"
        when 'hpux'
          ""
        when 'java'
          "if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.BROWSE)) {" \
            "Desktop.getDesktop().browse(new URI(#{uri}));" \
          "}"
        when 'dalvik'
          ""
        when 'dotnet'
          "System.Diagnostics.Process.Start(#{uri});"
        when 'linux'
          "xdg-open #{uri}"
        when 'mingw32'
          "start #{uri}"
        when 'netbsdelf'
          "xdg-open #{uri}"
        when 'openbsd'
          "xdg-open #{uri}"
        when 'bitrig'
          "xdg-open #{uri}"
        when 'solaris'
          if version < 11
            "sdtwebclient #{uri}"
          else
            "xdg-open #{uri}"
          end
        else
          ""
        end
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
        local_os = Gem::Platform.local.os
        version = Gem::Platform.local.version
        open_browser_cmd = open_default_browser_cmd(local_os, version, uri)

        if !open_browser_cmd.empty?
          system(open_browser_cmd)
        else
          puts "The command 'web' is not supported on your platform."
        end
      end

    end
  end
end
