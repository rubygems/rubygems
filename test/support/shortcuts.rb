module Support
  module Shortcuts

    # Construct a new Gem::Dependency from +name+ and +requirements+.

    def dep name, *requirements
      Gem::Dependency.new name, requirements
    end

    # Construct a new Gem::Requirement from +requirements+.

    def req *requirements
      return requirements.first if Gem::Requirement === requirements.first
      Gem::Requirement.create requirements
    end

    # Construct a new Gem::Version from +string+.

    def v string
      Gem::Version.create string
    end
  end
end
