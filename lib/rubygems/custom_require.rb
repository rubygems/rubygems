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
    if Gem::Specification.unresolved_deps.empty? then
      gem_original_require path
    else
      spec = Gem::Specification.find { |s|
        s.activated? and s.contains_requirable_file? path
      }

      unless spec then
        found_specs = Gem::Specification.find_in_unresolved path

        # If there are no directly unresolved gems, then try and find +path+
        # in any gems that are available via the currently unresolved gems.
        # For example, given:
        #
        #   a => b => c => d
        #
        # If a and b are currently active with c being unresolved and d.rb is
        # requested, then find_in_unresolved_tree will find d.rb in d because
        # it's a dependency of c.
        #
        if found_specs.empty? then
          found_specs = Gem::Specification.find_in_unresolved_tree path

          found_specs.each do |found_spec|
            found_spec.activate
          end

        # We found +path+ directly in an unresolved gem. Now we figure out, of
        # the possible found specs, which one we should activate.
        else

          # Check that all the found specs are just different
          # versions of the same gem
          names = found_specs.map(&:name).uniq

          if names.size > 1
            raise Gem::LoadError, "ambigious path (#{path}) found in multiple gems: #{names.join(', ')}"
          end

          # Ok, now find a gem that has no conflicts, starting
          # at the highest version.
          valid = found_specs.select { |s| s.conflicts.empty? }.last

          unless valid
            raise Gem::LoadError, "unable to find a version of '#{names.first}' to activate"
          end

          valid.activate
        end
      end

      return gem_original_require path
    end
  rescue LoadError => load_error
    if load_error.message.end_with?(path) and Gem.try_activate(path) then
      return gem_original_require(path)
    end

    raise load_error
  end

  private :require

end

