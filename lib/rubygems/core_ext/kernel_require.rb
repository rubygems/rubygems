#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module Kernel

  if defined?(gem_original_require) then
    # Ruby ships with a custom_require, override its require
    remove_method :require
  else
    ##
    # The Kernel#require from before RubyGems was loaded.

    alias gem_original_require require
    private :gem_original_require
  end

  ##
  # When RubyGems is required, Kernel#require is replaced with our own which
  # is capable of loading gems on demand.
  #
  # When you call <tt>require 'x'</tt>, this is what happens:
  # * If the file can be loaded from the existing Ruby loadpath, it
  #   is.
  # * Otherwise, installed gems are searched for a file that matches.
  #   If it's found in gem 'y', that gem is activated (added to the
  #   loadpath).
  #
  # The normal <tt>require</tt> functionality of returning false if
  # that file has already been loaded is preserved.

  def require path
    path = Gem.resolve!(path)
    gem_original_require(path)
  end

  private :require

end

