class Gem::DependencyResolver::VendorSpecification < Gem::DependencyResolver::Specification

  attr_reader :spec

  def initialize set, spec, source=nil
    super()

    @set    = set
    @source = source
    @spec   = spec
  end

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec and
      @source == other.source
  end

  def dependencies
    @spec.dependencies
  end

  def full_name
    "#{@spec.name}-#{@spec.version}"
  end

  def name
    @spec.name
  end

  def platform
    @spec.platform
  end

  def version
    @spec.version
  end

end

