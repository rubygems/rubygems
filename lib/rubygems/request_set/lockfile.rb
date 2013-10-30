class Gem::RequestSet::Lockfile

  def initialize request_set
    @set = request_set
  end

  def to_s
    @set.resolve

    out = []

    out << "GEM"

    groups = @set.sorted_requests.group_by do |request|
      request.spec.source.uri
    end

    groups.map do |group, requests|
      out << "  remote: #{group}"
      out << "  specs:"
      requests.each do |request|
        out << "    #{request.name} (#{request.version})"
        request.full_spec.dependencies.each do |dependency|
          out << "      #{dependency.name}"
        end
      end
    end

    out << nil
    out << "PLATFORMS"

    out << "  #{Gem::Platform::RUBY}"

    out << nil
    out << "DEPENDENCIES"

    @set.dependencies.map do |dependency|
      requirement = " (#{dependency.requirement})" unless
        Gem::Requirement.default == dependency.requirement

      out << "  #{dependency.name}#{requirement}"
    end

    out << nil

    out.join "\n"
  end

end

