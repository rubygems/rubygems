require 'rubygems'
require 'rubygems/dependency'
require 'rubygems/exceptions'

require 'uri'
require 'net/http'

module Gem

  # Raised when a DependencyConflict reaches the toplevel.
  # Indicates which dependencies were incompatible.
  #
  class DependencyResolutionError < Gem::Exception
    def initialize(conflict)
      @conflict = conflict
      a, b = conflicting_dependencies

      super "unable to resolve conflicting dependencies '#{a}' and '#{b}'"
    end

    attr_reader :conflict

    def conflicting_dependencies
      @conflict.conflicting_dependencies
    end
  end

  ##
  # Raised when a dependency requests a gem for which there is
  # no spec.

  class UnsatisfiableDependencyError < Gem::Exception
    def initialize(dep)
      requester = dep.requester ? dep.requester.request : '(unknown)'

      super "Unable to resolve dependency: #{requester} requires #{dep}"

      @dependency = dep
    end

    attr_reader :dependency
  end

  ##
  # Backwards compatible typo'd exception class for early RubyGems 2.0.x

  UnsatisfiableDepedencyError = UnsatisfiableDependencyError # :nodoc:

  # Raised when dependencies conflict and create the inability to
  # find a valid possible spec for a request.
  #
  class ImpossibleDependenciesError < Gem::Exception
    def initialize(request, conflicts)
      s = conflicts.size == 1 ? "" : "s"
      super "detected #{conflicts.size} conflict#{s} with dependency #{request.dependency}"
      @request = request
      @conflicts = conflicts
    end

    def dependency
      @request.dependency
    end

    attr_reader :conflicts
  end

  # Given a set of Gem::Dependency objects as +needed+ and a way
  # to query the set of available specs via +set+, calculates
  # a set of ActivationRequest objects which indicate all the specs
  # that should be activated to meet the all the requirements.
  #
  class DependencyResolver

    def self.compose_sets(*sets)
      ComposedSet.new(*sets)
    end

    attr_accessor :development

    # Create DependencyResolver object which will resolve
    # the tree starting with +needed+ Depedency objects.
    #
    # +set+ is an object that provides where to look for
    # specifications to satisify the Dependencies. This
    # defaults to IndexSet, which will query rubygems.org.
    #
    def initialize(needed, set=IndexSet.new)
      @set = set || IndexSet.new # Allow nil to mean IndexSet
      @needed = needed

      @conflicts    = nil
      @development  = false
      @missing      = []
      @soft_missing = false
    end

    # When a missing dependency, don't stop. Just go on and record
    # what was missing.
    #
    attr_accessor :soft_missing
    attr_reader :missing

    # Provide a DependencyResolver that queries only against
    # the already installed gems.
    #
    def self.for_current_gems(needed)
      new needed, CurrentSet.new
    end

    # Contains all the conflicts encountered while doing resolution
    #
    attr_reader :conflicts

    # Proceed with resolution! Returns an array of ActivationRequest
    # objects.
    #
    def resolve
      @conflicts = []

      needed = @needed.map { |n| DependencyRequest.new(n, nil) }

      res = resolve_for needed, []

      if res.kind_of? DependencyConflict
        raise DependencyResolutionError.new(res)
      end

      res
    end

    def requests(s, act)
      reqs = []
      s.dependencies.each do |d|
        next if d.type == :development and not @development
        reqs << DependencyRequest.new(d, act)
      end

      @set.prefetch(reqs)

      reqs
    end

    # The meat of the algorithm. Given +needed+ DependencyRequest objects
    # and +specs+ being a list to ActivationRequest, calculate a new list
    # of ActivationRequest objects.
    #
    def resolve_for(needed, specs)
      until needed.empty?
        dep = needed.shift

        # If there is already a spec activated for the requested name...
        if existing = specs.find { |s| dep.name == s.name }

          # then we're done since this new dep matches the
          # existing spec.
          next if dep.matches_spec? existing

          # There is a conflict! We return the conflict
          # object which will be seen by the caller and be
          # handled at the right level.

          # If the existing activation indicates that there
          # are other possibles for it, then issue the conflict
          # on the dep for the activation itself. Otherwise, issue
          # it on the requester's request itself.
          #
          if existing.others_possible?
            conflict = DependencyConflict.new(dep, existing)
          else
            depreq = existing.request.requester.request
            conflict = DependencyConflict.new(depreq, existing, dep)
          end
          @conflicts << conflict

          return conflict
        end

        # Get a list of all specs that satisfy dep
        possible = @set.find_all(dep)

        case possible.size
        when 0
          @missing << dep

          unless @soft_missing
            # If there are none, then our work here is done.
            raise UnsatisfiableDependencyError.new(dep)
          end
        when 1
          # If there is one, then we just add it to specs
          # and process the specs dependencies by adding
          # them to needed.

          spec = possible.first
          act =  ActivationRequest.new(spec, dep, false)

          specs << act

          # Put the deps for at the beginning of needed
          # rather than the end to match the depth first
          # searching done by the multiple case code below.
          #
          # This keeps the error messages consistent.
          needed = requests(spec, act) + needed
        else
          # There are multiple specs for this dep. This is
          # the case that this class is built to handle.

          # Sort them so that we try the highest versions
          # first.
          possible = possible.sort_by { |s| [s.source, s.version] }

          # We track the conflicts seen so that we can report them
          # to help the user figure out how to fix the situation.
          conflicts = []

          # To figure out which to pick, we keep resolving
          # given each one being activated and if there isn't
          # a conflict, we know we've found a full set.
          #
          # We use an until loop rather than #reverse_each
          # to keep the stack short since we're using a recursive
          # algorithm.
          #
          until possible.empty?
            s = possible.pop

            # Recursively call #resolve_for with this spec
            # and add it's dependencies into the picture...

            act = ActivationRequest.new(s, dep)

            try = requests(s, act) + needed

            res = resolve_for(try, specs + [act])

            # While trying to resolve these dependencies, there may
            # be a conflict!

            if res.kind_of? DependencyConflict
              # The conflict might be created not by this invocation
              # but rather one up the stack, so if we can't attempt
              # to resolve this conflict (conflict isn't with the spec +s+)
              # then just return it so the caller can try to sort it out.
              return res unless res.for_spec? s

              # Otherwise, this is a conflict that we can attempt to fix
              conflicts << [s, res]

              # Optimization:
              #
              # Because the conflict indicates the dependency that trigger
              # it, we can prune possible based on this new information.
              #
              # This cuts down on the number of iterations needed.
              possible.delete_if { |x| !res.dependency.matches_spec? x }
            else
              # No conflict, return the specs
              return res
            end
          end

          # We tried all possibles and nothing worked, so we let the user
          # know and include as much information about the problem since
          # the user is going to have to take action to fix this.
          raise ImpossibleDependenciesError.new(dep, conflicts)
        end
      end

      specs
    end
  end
end

require 'rubygems/dependency_resolver/api_set'
require 'rubygems/dependency_resolver/api_specification'
require 'rubygems/dependency_resolver/activation_request'
require 'rubygems/dependency_resolver/composed_set'
require 'rubygems/dependency_resolver/current_set'
require 'rubygems/dependency_resolver/dependency_conflict'
require 'rubygems/dependency_resolver/dependency_request'
require 'rubygems/dependency_resolver/index_set'
require 'rubygems/dependency_resolver/index_specification'
require 'rubygems/dependency_resolver/installed_specification'
require 'rubygems/dependency_resolver/installer_set'

