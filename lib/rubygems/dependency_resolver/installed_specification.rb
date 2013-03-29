class Gem::DependencyResolver::InstalledSpecification

  def initialize set, spec
    @set    = set
    @source = nil
    @spec   = spec
  end

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec
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

  def source
    @source ||= Gem::Source::Installed.new @spec
  end

  def version
    @spec.version
  end

end

