class Gem::RequestSet::Lockfile

  def initialize request_set
    @set = request_set
  end

  def add_DEPENDENCIES out # :nodoc:
    out << "DEPENDENCIES"

    @set.dependencies.sort.map do |dependency|
      source = @requests.find do |req|
        req.name == dependency.name and
          req.spec.class == Gem::DependencyResolver::VendorSpecification
      end

      source_dep = '!' if source

      requirement = dependency.requirement

      out << "  #{dependency.name}#{source_dep}#{requirement.for_lockfile}"
    end

    out << nil
  end

  def add_GEM out # :nodoc:
    out << "GEM"

    source_groups = @spec_groups.values.flatten.group_by do |request|
      request.spec.source.uri
    end

    source_groups.map do |group, requests|
      out << "  remote: #{group}"
      out << "  specs:"
      requests.sort_by { |request| request.name }.each do |request|
        platform = "-#{request.spec.platform}" unless
          Gem::Platform::RUBY == request.spec.platform
        out << "    #{request.name} (#{request.version}#{platform})"
        request.full_spec.dependencies.sort.each do |dependency|
          requirement = dependency.requirement
          out << "      #{dependency.name}#{requirement.for_lockfile}"
        end
      end
    end

    out << nil
  end

  def add_PATH out # :nodoc:
    return unless path_requests =
      @spec_groups.delete(Gem::DependencyResolver::VendorSpecification)

    out << "PATH"
    path_requests.each do |request|
      out << "  remote: #{request.spec.source.uri}"
      out << "  specs:"
      out << "    #{request.name} (#{request.version})"
    end

    out << nil
  end

  def add_PLATFORMS out # :nodoc:
    out << "PLATFORMS"

    platforms = @requests.map { |request| request.spec.platform }.uniq
    platforms.delete Gem::Platform::RUBY if platforms.length > 1

    platforms.each do |platform|
      out << "  #{platform}"
    end

    out << nil
  end

  def to_s
    @set.resolve

    out = []

    @requests = @set.sorted_requests

    @spec_groups = @requests.group_by do |request|
      request.spec.class
    end

    add_PATH out

    add_GEM out

    add_PLATFORMS out

    add_DEPENDENCIES out

    out.join "\n"
  end

end

