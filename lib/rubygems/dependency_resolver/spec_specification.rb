##
# The DependencyResolver::SpecSpecification contains common functionality for
# DependencyResolver specifications that are backed by a Gem::Specification.

class Gem::DependencyResolver::SpecSpecification < Gem::DependencyResolver::Specification

  attr_reader :spec # :nodoc:

  def initialize set, spec, source = nil
    @set    = set
    @source = source
    @spec   = spec
  end

  def dependencies
    spec.dependencies
  end

  def full_name
    "#{spec.name}-#{spec.version}"
  end

  def name
    spec.name
  end

  def platform
    spec.platform
  end

  def version
    spec.version
  end

end

