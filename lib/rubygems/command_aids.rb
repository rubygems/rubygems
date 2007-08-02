#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'

# The following mixin methods aid in the retrieving of information
# from the command line.
module Gem::CommandAids

  # Get the single gem name from the command line.  Fail if there is
  # no gem name or if there is more than one gem name given.
  def get_one_gem_name
    args = options[:args]
    if args.nil? or args.empty?
      fail Gem::CommandLineError,
        "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
    end
    if args.size > 1
      fail Gem::CommandLineError,
        "Too many gem names (#{args.join(', ')}); please specify only one"
    end
    args.first
  end

  # Get all gem names from the command line.
  def get_all_gem_names
    args = options[:args]
    if args.nil? or args.empty?
      raise Gem::CommandLineError,
            "Please specify at least one gem name (e.g. gem build GEMNAME)"
    end
    gem_names = args.select { |arg| arg !~ /^-/ }
  end

  # Get a single optional argument from the command line.  If more
  # than one argument is given, return only the first. Return nil if
  # none are given.
  def get_one_optional_argument
    args = options[:args] || []
    args.first
  end

  # True if +long+ begins with the characters from +short+.
  def begins?(long, short)
    return false if short.nil?
    long[0, short.length] == short
  end

end

