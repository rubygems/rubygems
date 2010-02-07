module Support
  module Shortcuts

    # Construct a new Gem::Dependency.

    def dep name, *requirements
      Gem::Dependency.new name, *requirements
    end

    # Construct a new Gem::Requirement.

    def req *requirements
      return requirements.first if Gem::Requirement === requirements.first
      Gem::Requirement.create requirements
    end

    # Construct a new Gem::Specification.

    def spec name, version, &block
      Gem::Specification.new name, v(version), &block
    end

    # Construct a new Gem::Version.

    def v string
      Gem::Version.create string
    end
  end
end
