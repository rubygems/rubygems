##
# Used internally to indicate that a dependency conflicted
# with a spec that would be activated.

class Gem::DependencyResolver::DependencyConflict

  attr_reader :activated

  attr_reader :dependency

  def initialize(dependency, activated, failed_dep=dependency)
    @dependency = dependency
    @activated = activated
    @failed_dep = failed_dep
  end

  ##
  # Return the 2 dependency objects that conflicted

  def conflicting_dependencies
    [@failed_dep.dependency, @activated.request.dependency]
  end

  def for_spec?(spec)
    @dependency.name == spec.name
  end

  ##
  # Return the Specification that listed the dependency

  def requester
    @failed_dep.requester
  end

end

