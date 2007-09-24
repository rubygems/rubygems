#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'

# Mixin methods for --version and --platform Gem::Command options.
module Gem::VersionOption

  # Add the --platform option to the option parser.
  def add_platform_option(task = command, *wrap)
    OptionParser.accept Gem::Platform do |value|
      Gem::Platform.new value
    end

    add_option('--platform PLATFORM', Gem::Platform,
               "Specify the platform of gem to #{task}", *wrap) do
                 |value, options|
      options[:platform] = value
    end
  end

  # Add the --version option to the option parser.
  def add_version_option(task = command, *wrap)
    OptionParser.accept Gem::Requirement do |value|
      Gem::Requirement.new value
    end

    add_option('-v', '--version VERSION', Gem::Requirement,
               "Specify version of gem to #{task}", *wrap) do
                 |value, options|
      options[:version] = value
    end
  end

end

