#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'

##
# The Dependency class holds a Gem name and a Gem::Requirement
class Gem::Dependency
  TYPES = [
    :runtime,
    :development
  ]

  attr_accessor :name

  attr_reader :type

  attr_writer :version_requirements

  def <=>(other)
    [@name] <=> [other.name]
  end

  ##
  # Constructs the dependency
  #
  # name:: [String] name of the Gem
  # version_requirements:: [String Array] version requirement (e.g. ["> 1.2"])
  #
  def initialize(name, version_requirements, type=:runtime)
    @name = name

    unless TYPES.include? type
      raise ArgumentError, "Valid types are #{TYPES.inspect}, not #{@type.inspect}"
    end

    @type = type

    @version_requirements = Gem::Requirement.create version_requirements
    @version_requirement = nil   # Avoid warnings.
  end

  def version_requirements
    normalize if defined? @version_requirement and @version_requirement
    @version_requirements
  end

  def requirement_list
    version_requirements.as_list
  end

  alias requirements_list requirement_list

  def normalize
    ver = @version_requirement.instance_eval { @version }
    @version_requirements = Gem::Requirement.new([ver])
    @version_requirement = nil
  end

  def to_s # :nodoc:
    "#{name} (#{version_requirements}#{", #{type}" if type != :runtime})"
  end

  def ==(other) # :nodoc:
    self.class === other &&
      self.name == other.name &&
      self.type == other.type &&
      self.version_requirements == other.version_requirements
  end

  def hash
    name.hash + type.hash + version_requirements.hash
  end

end

