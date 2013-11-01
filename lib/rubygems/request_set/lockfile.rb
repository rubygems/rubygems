require 'pathname'

class Gem::RequestSet::Lockfile

  ##
  # Creates a new Lockfile for the given +request_set+ and +gem_deps_file+
  # location.

  def initialize request_set, gem_deps_file
    @set           = request_set
    @gem_deps_file = Pathname(gem_deps_file).expand_path
    @gem_deps_dir  = @gem_deps_file.dirname

    @line           = 0
    @line_pos       = 0
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
      directory = Pathname(request.spec.source.uri).expand_path

      out << "  remote: #{directory.relative_path_from @gem_deps_dir}"
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

  ##
  # Calculates the column (by byte) and the line of the current token based on
  # +byte_offset+.

  def token_pos byte_offset # :nodoc:
    [byte_offset - @line_pos, @line]
  end

  def token_stream # :nodoc:
    return enum_for __method__ unless block_given?

    @line     = 0
    @line_pos = 0
    @input    = File.read "#{@gem_deps_file}.lock"
    s         = StringScanner.new @input

    until s.eos? do
      pos = s.pos

      # leading whitespace is for the user's convenience
      next if s.scan(/ +/)

      case
      when s.scan(/\r?\n/) then
        token = [:newline, nil, *token_pos(pos)]
        @line_pos = s.pos
        @line += 1
        yield token
      when s.scan(/[A-Z]+/) then
        yield [:section, s.matched, *token_pos(pos)]
      when s.scan(/([a-z]+):\s/) then
        s.pos -= 1 # rewind for possible newline
        yield [:entry, s[1], *token_pos(pos)]
      when s.scan(/\(/) then
        yield [:l_paren, nil, *token_pos(pos)]
      when s.scan(/\)/) then
        yield [:r_paren, nil, *token_pos(pos)]
      when s.scan(/[^\s)]*/) then
        yield [:text, s.matched, *token_pos(pos)]
      else
        raise "BUG: can't create token for: #{s.string[s.pos..-1].inspect}"
      end
    end
  end

end

