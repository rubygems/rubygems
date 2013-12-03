##
# The LockSpecification comes from a lockfile (Gem::RequestSet::Lockfile).
#
# A LockSpecification's dependency information is pre-filled from the
# lockfile.

class Gem::Resolver::LockSpecification < Gem::Resolver::Specification

  def initialize set, name, version, source, platform
    super()

    @name     = name
    @platform = platform
    @set      = set
    @source   = source
    @version  = version

    @dependencies = []
    @spec         = nil
  end

  ##
  # This is a null install as a locked specification is considered installed.
  # +options+ are ignored.

  def install options
    yield nil
  end

  def dependencies= dependencies # :nodoc:
    @dependencies.concat dependencies
  end

  ##
  # A specification constructed from the lockfile is returned

  def spec
    @spec ||= Gem::Specification.new do |s|
      s.name     = @name
      s.version  = @version
      s.platform = @platform

      s.dependencies.concat @dependencies
    end
  end

end

