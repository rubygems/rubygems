#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/source_index'

module Kernel
  alias gem_original_require require # :nodoc:

  #
  # We replace Ruby's require with our own, which is capable of
  # loading gems on demand.
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
  #
  def require(path) # :nodoc:
    gem_original_require path
  rescue LoadError => load_error
    begin
      if spec = Gem.searcher.find(path)
        Gem.activate(spec.name, false, "= #{spec.version}")
        gem_original_require path
      else
        raise load_error
      end
    end
  end
end  # module Kernel

module Gem

  #
  # GemPathSearcher has the capability to find loadable files inside
  # gems.  It generates data up front to speed up searches later.
  #
  class GemPathSearcher
    
    #
    # Initialise the data we need to make searches later.
    #
    def initialize
      # We want a record of all the installed gemspecs, in the order
      # we wish to examine them.
      @gemspecs = init_gemspecs
      # Map gem spec to glob of full require_path directories.
      # Preparing this information may speed up searches later.
      @lib_dirs = {}
      @gemspecs.each do |spec|
        @lib_dirs[spec.object_id] = lib_dirs(spec)
      end
    end

    # 
    # Look in all the installed gems until a matching _path_ is found.
    # Return the _gemspec_ of the gem where it was found.  If no match
    # is found, return nil.
    #
    # The gems are searched in alphabetical order, and in reverse
    # version order.
    #
    # For example:
    #
    #   find('log4r')              # -> (log4r-1.1 spec)
    #   find('log4r.rb')           # -> (log4r-1.1 spec)
    #   find('rake/rdoctask')      # -> (rake-0.4.12 spec)
    #   find('foobarbaz')          # -> nil
    #
    # Matching paths can have various suffixes ('.rb', '.so', and
    # others), which may or may not already be attached to _file_.
    # This method doesn't care about the full filename that matches;
    # only that there is a match.
    # 
    def find(path)
      @gemspecs.each do |spec|
        return spec if matching_file(spec, path)
      end
      nil
    end

    private

    # Attempts to find a matching path using the require_paths of the
    # given _spec_.
    #
    # Some of the intermediate results are cached in @lib_dirs for
    # speed.
    def matching_file(spec, path)  # :doc:
      glob = File.join @lib_dirs[spec.object_id], "#{path}#{Gem.suffix_pattern}"
      return true unless Dir[glob].select { |f| File.file?(f.untaint) }.empty?
    end

    # Return a list of all installed gemspecs, sorted by alphabetical
    # order and in reverse version order.
    def init_gemspecs
      Gem.source_index.map { |_, spec| spec }.sort { |a,b|
        (a.name <=> b.name).nonzero? || (b.version <=> a.version)
      }
    end

    # Returns library directories glob for a gemspec.  For example,
    #   '/usr/local/lib/ruby/gems/1.8/gems/foobar-1.0/{lib,ext}'
    def lib_dirs(spec)
      "#{spec.full_gem_path}/{#{spec.require_paths.join(',')}}"
    end

  end  # class Gem::GemPathLoader

end  # module Gem

