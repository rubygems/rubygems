class Gem::RequestSet::Lockfile

  def initialize request_set
    @set = request_set
  end

  def to_s
    @set.resolve

    out = []

    requests = @set.sorted_requests

    spec_groups = @set.sorted_requests.group_by do |request|
      request.spec.class
    end

    path_requests =
      spec_groups.delete Gem::DependencyResolver::VendorSpecification

    if path_requests then
      out << "PATH"
      path_requests.each do |request|
        out << "  remote: #{request.spec.source.uri}"
        out << "  specs:"
        out << "    #{request.name} (#{request.version})"
      end

      out << nil
    end

    out << "GEM"

    source_groups = spec_groups.values.flatten.group_by do |request|
      request.spec.source.uri
    end

    source_groups.map do |group, requests|
      out << "  remote: #{group}"
      out << "  specs:"
      requests.each do |request|
        out << "    #{request.name} (#{request.version})"
        request.full_spec.dependencies.each do |dependency|
          spec_requirement = " (#{dependency.requirement})" unless
            Gem::Requirement.default == dependency.requirement
          out << "      #{dependency.name}#{spec_requirement}"
        end
      end
    end

    out << nil
    out << "PLATFORMS"

    out << "  #{Gem::Platform::RUBY}"

    out << nil
    out << "DEPENDENCIES"

    @set.dependencies.map do |dependency|
      source = requests.find do |req|
        req.name == dependency.name and
          req.spec.class == Gem::DependencyResolver::VendorSpecification
      end

      source_dep = '!' if source

      dep_requirement = " (#{dependency.requirement})" unless
        Gem::Requirement.default == dependency.requirement

      out << "  #{dependency.name}#{source_dep}#{dep_requirement}"
    end

    out << nil

    out.join "\n"
  end

end

