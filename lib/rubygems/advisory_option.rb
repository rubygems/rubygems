# frozen_string_literal: true
require 'rubygems/remote_fetcher'

##
# Utility methods for using the RubyGems API.

module Gem::AdvisoryOption

  ##
  # Option to ignore a CVE while using the gem audit command.

  def add_ignore_cve_option
    add_option('-i', '--ignore-cve CVENUMBER', 'Ignore CVE while gem audit', ) do |value, options|
      options[:ignore_cve] = value
    end
  end
end
