#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


module Gem
  class DependencyList
    def self.from_source_index(src_index)
      deps = DependencyList.new
      src_index.each do |full_name, spec|
        deps.add(spec)
      end
      deps
    end

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

    # Is is ok to remove a gem from the dependency list?
    #
    # If removing the gemspec creates breaks a currently ok dependency,
    # then it is NOT ok to remove the gem.
    def ok_to_remove?(full_name)
      gem_to_remove = find_name(full_name)
      siblings = @specs.find_all { |s|
        s.name == gem_to_remove.name &&
          s.full_name != gem_to_remove.full_name        
      }
      deps = []
      @specs.each do |spec|
        spec.dependencies.each do |dep|
          deps << dep if gem_to_remove.satisfies_requirement?(dep)
        end
      end
      deps.all? { |dep|
        siblings.any? { |s| 
          s.satisfies_requirement?(dep)
        }
      }
    end

    # Return a list of the specifications in the dependency list,
    # sorted in order so that no spec in the list depends on a gem
    # earlier in the list.
    #
    # This is useful when removing gems from a set of installed gems.
    # By removing them in the returned order, you don't get into as
    # many dependency issues.
    #
    # If there are circular dependencies (yuck!), then gems will be
    # returned in order until only the circular dependents and anything
    # they reference are left.  Then arbitrary gemspecs will be returned
    # until the circular dependency is broken, after which gems will be
    # returned in dependency order again.  
    def dependency_order
      result = []
      disabled = {}
      predecessors = build_predecessors
      while disabled.size < @specs.size
        candidate = @specs.find { |spec|
          ! disabled[spec.full_name] &&
            active_count(predecessors[spec.full_name], disabled) == 0
        }
        if candidate
          disabled[candidate.full_name] = true
          result << candidate
        elsif candidate = @specs.find { |spec| ! disabled[spec.full_name] }
          # This case handles circular dependencies.  Just choose a
          # candidate and move on.
          disabled[candidate.full_name] = true
          result << candidate
        else
          # We should never get here, but just in case we will terminate 
          # the loop.
          break
        end
      end
      result
    end

    private

    # Count the number of gemspecs in the list +specs+ that are still
    # active (e.g. not listed in the ignore hash).
    def active_count(specs, ignored)
      result = 0
      specs.each do |spec|
        result += 1 unless ignored[spec.full_name]
      end
      result
    end

    # Return a hash of predecessors.  E.g. results[spec.full_name] is a
    # list of gemspecs that have a dependency satisfied by spec.
    def build_predecessors
      result = Hash.new { |h,k| h[k] = [] }
      @specs.each do |spec|
        @specs.each do |other|
          next if spec.full_name == other.full_name
          other.dependencies.each do |dep|
            if spec.satisfies_requirement?(dep)
              result[spec.full_name] << other
            end
          end
        end
      end
      result
    end

  end
end
