class Gem::Resolver::LocalSpecification < Gem::Resolver::SpecSpecification

  ##
  # Returns +true+ if this gem is installable for the current platform.

  def installable_platform?
    return true if @source.kind_of? Gem::Source::SpecificFile

    super
  end

end

