#!/usr/bin/env ruby

module Gem
  class DependencyList
    def initialize
      @specs = []
    end

    # Are all the dependencies in the list satisfied?
    def ok?
      @specs.all? { |spec|
	spec.dependencies.all? { |dep|
	  @specs.find { |s| s.satisfies_requirement?(dep) }
	}
      }
    end

    # Add a gemspec to the dependency list.
    def add(gemspec)
      @specs << gemspec
    end

    def find_name(full_name)
      @specs.find { |spec| spec.full_name == full_name }
    end

    def remove_by_name(full_name)
      @specs.delete_if { |spec| spec.full_name == full_name }
    end

    # Return a list of the specifications in the dependency list,
    # sorted in order so that no spec in the list depends on a gem
    # earlier in the list.
    #
    # This is useful when removing gems from a set of installed gems.
    # By removing them in the returned order, you don't get into as
    # many dependency issues.
    def dependency_order
      result = []
      disabled = {}
      while disabled.size < @specs.size
	candidate = @specs.find { |spec| ! disabled[spec.full_name] && top_level?(spec, disabled) }
	if candidate
	  disabled[candidate.full_name] = true
	  result << candidate
	elsif candidate = @specs.find { |spec| ! disabled[spec.full_name] }
	  # This case handles circular dependencies.  Just choose a candidate and move on.
	  disabled[candidate.full_name] = true
	  result << candidate
	else
	  # We should never get here, but just in case we will terminate the loop.
	  break
	end
      end
      result
    end

    private

    # Is the given gemspec is a top level spec in the dependency list?
    #
    # A spec is top level when there are no (non-ignored) specs in the
    # list that depend on it.  Specs listed in +ignored+ hash are
    # ignored when calculating the top level status.
    def top_level?(spec, ignored)
      @specs.each do |s|
	next if ignored[spec.full_name]
	next if spec.full_name == s.full_name
	s.dependencies.each do |dep|
	  if spec.satisfies_requirement?(dep)
	    return false
	  end
	end
      end
      true
    end

  end
end
