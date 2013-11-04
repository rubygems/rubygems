class Gem::DependencyResolver::VendorSpecification < Gem::DependencyResolver::SpecSpecification

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec and
      @source == other.source
  end

end

