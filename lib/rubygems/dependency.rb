##
# The Dependency class holds a Gem name and a Gem::Requirement.

class Gem::Dependency

  ##
  # Valid dependency types.
  #--
  # When this list is updated, be sure to change
  # Gem::Specification::CURRENT_SPECIFICATION_VERSION as well.

  TYPES = [:development, :runtime]

  ##
  # Dependency name or regular expression.

  attr_accessor :name

  ##
  # Dependency type.

  attr_reader :type

  ##
  # What does this dependency require?

  attr_reader :requirement

  ##
  # Constructs a dependency with +name+ and +requirements+. The last
  # argument can optionally be the dependency type, which defaults to
  # <tt>:runtime</tt>.

  def initialize name, *requirements
    type         = Symbol === requirements.last ? requirements.pop : :runtime
    requirements = requirements.first if 1 == requirements.length # unpack

    unless TYPES.include? type
      raise ArgumentError, "Valid types are #{TYPES.inspect}, "
        + "not #{@type.inspect}"
    end

    @name        = name
    @requirement = Gem::Requirement.create requirements
    @type        = type
  end

  ##
  # A dependency's hash is the XOR of the hashes of +name+, +type+,
  # and +requirement+.

  def hash
    name.hash ^ type.hash ^ requirement.hash
  end

  def inspect # :nodoc:
    "<%s type=%p name=%p requirements=%p>" %
      [self.class, @type, @name, requirement.to_s]
  end

  def requirements_list # FIX: stop using this
    requirement.as_list
  end

  def to_s # :nodoc:
    "#{name} (#{requirement}, #{type})"
  end

  def pretty_print(q) # :nodoc:
    q.group 1, 'Gem::Dependency.new(', ')' do
      q.pp name
      q.text ','
      q.breakable

      q.pp requirement

      q.text ','
      q.breakable

      q.pp type
    end
  end

  def version_requirements # :nodoc:
    warn "Gem::Dependency#version_requirements deprecated, " +
      " use Gem::Dependency#requirement.\n#{caller.join "\n"}"

    requirement
  end

  alias_method :version_requirement, :version_requirements

  def == other # :nodoc:
    Gem::Dependency === other &&
      self.name        == other.name &&
      self.type        == other.type &&
      self.requirement == other.requirement
  end

  ##
  # Dependencies are ordered by name.

  def <=> other
    [@name] <=> [other.name]
  end

  ##
  # Uses this dependency as a pattern to compare to +other+. This
  # dependency will match if the name matches the other's name, and
  # other has only an equal version requirement that satisfies this
  # dependency.

  def =~ other
    unless Gem::Dependency === other
      other = Gem::Dependency.new other.name, other.version rescue return false
    end

    pattern = name
    pattern = /\A#{Regexp.escape pattern}\Z/ unless Regexp === pattern

    return false unless pattern =~ other.name

    reqs = other.requirement.requirements

    return false unless reqs.length == 1
    return false unless reqs.first.first == '='

    version = reqs.first.last

    requirement.satisfied_by? version
  end
end
