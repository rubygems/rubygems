#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'

# Mixin methods for the version command.
module Gem::VersionOption

  # Add the version option to the option parser.
  def add_version_option(taskname, *wrap)
    add_option('-v', '--version VERSION',
               "Specify version of gem to #{taskname}", *wrap) do
                 |value, options|
      options[:version] = value
    end
  end

end

