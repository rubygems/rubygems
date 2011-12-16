module Gem

  # Raised when a DependencyConflict reaches the toplevel.
  # Indicates which dependencies were incompatible.
  #
  class DependencyResolutionError < RuntimeError
    def initialize(conflict)
      super "error resolving dependencies"

      @conflict = conflict
    end

    attr_reader :conflict

    def conflicting_dependencies
      @conflict.conflicting_dependencies
    end
  end

  # Raised when a dependency requests a gem for which there is
  # no spec.
  #
  class UnsatisfiableDepedencyError < StandardError
    def initialize(dep)
      super "No gem found for dependency - #{dep}"
      @dependency = dep
    end

    attr_reader :dependency
  end

  # Raised when dependencies conflict and create the inability to
  # find a valid possible spec for a request.
  #
  class ImpossibleDependenciesError < StandardError
    def initialize(request, conflicts)
      @request = request
      @conflicts = conflicts
    end

    def dependency
      @request.dep
    end

    attr_reader :conflicts
  end

  # Given a set of Gem::Dependency objects as +needed+ and a way
  # to query the set of available specs via +available+, calculates
  # a set of ActivationRequest objects which indicate all the specs
  # that should be activated to meet the all the requirements.
  #
  class DependencyResolver
    def initialize(available, needed)
      @available = available
      @needed = needed

      @possible = Hash.new { |h,k| h[k] = [] }

      @debug = false

      @conflicts = []
    end

    # Contains all the conflicts encountered while doing resolution
    #
    attr_reader :conflicts

    # Proceed with resolution! Returns an array of ActivationRequest
    # objects.
    #
    def resolve!
      needed = @needed.map { |n| DependencyRequest.new(n, nil) }

      res = resolve_for needed, []

      if res.kind_of? DependencyConflict
        raise DependencyResolutionError.new(res)
      end

      res
    end

    # Used internally to indicate that a dependency conflicted
    # with a spec that would be activated.
    #
    class DependencyConflict
      def initialize(dependency, activated)
        @dependency = dependency
        @activated = activated
      end

      attr_reader :dependency, :activated

      # Return the Specification that listed the dependency
      #
      def requester
        @dependency.spec
      end

      def for_spec?(spec)
        @dependency.name == spec.name
      end

      # Return the 2 dependency objects that conflicted
      #
      def conflicting_dependencies
        [@dependency.dep, @activated.for_dependency.dep]
      end
    end

    # Used Internally. Wraps a Depedency object to also track
    # which spec contained the Dependency.
    #
    class DependencyRequest
      def initialize(dep, spec)
        @dep = dep
        @spec = spec
      end

      attr_reader :dep, :spec

      def name
        @dep.name
      end

      def matches_spec?(spec)
        @dep.matches_spec? spec
      end

      def to_s
        @dep.to_s
      end

      def ==(other)
        case other
        when Dependency
          @dep == other
        when DependencyRequest
          @dep == other.dep && @spec == other.spec
        else
          false
        end
      end
    end

    # Specifies a Specification object that should be activated.
    # Also contains a dependency that was used to introduce this
    # activation.
    #
    class ActivationRequest
      def initialize(spec, dep)
        @spec = spec
        @for_dependency = dep
      end

      attr_reader :spec, :for_dependency

      # Return the ActivationRequest that contained the dependency
      # that we were activated for.
      #
      def parent
        @for_dependency.spec
      end

      def name
        @spec.name
      end

      def full_name
        @spec.full_name
      end

      def version
        @spec.version
      end

      def ==(other)
        case other
        when Gem::Specification
          @spec == other
        when ActivationRequest
          @spec == other.spec && @for_dependency == other.for_dependency
        else
          false
        end
      end
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

          conflict = DependencyConflict.new(dep, existing)
          @conflicts << conflict

          return conflict
        end

        # Get a list of all specs that satisfy dep
        possible = @available.find_all(dep)

        case possible.size
        when 0
          # If there are none, then our work here is done.
          raise UnsatisfiableDepedencyError.new(dep)
        when 1
          # If there is one, then we just add it to specs
          # and process the specs dependencies by adding
          # them to needed.

          spec = possible.first
          act =  ActivationRequest.new(spec, dep)

          specs << act

          # Put the deps for at the beginning of needed
          # rather than the end to match the depth first
          # searching done by the multiple case code below.
          #
          # This keeps the error messages consistent.
          more = spec.dependencies.map do |d|
                   DependencyRequest.new(d, act)
                 end

          needed = needed + more
        else
          # There are multiple specs for this dep. This is
          # the case that this class is built to handle.

          # Sort them so that we try the highest versions
          # first.
          possible = possible.sort_by { |s| s.version }

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

            try = needed + s.dependencies.map do |d|
                             DependencyRequest.new(d, act)
                           end

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
