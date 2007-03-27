#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'time'
require 'rubygems'
require 'rubygems/version'

class Time # :nodoc:
  def self.today
    Time.parse Time.now.strftime("%Y-%m-%d")
  end
end

module Gem
  
  # == Gem::Platform
  #
  # Available list of platforms for targeting Gem installations.
  # Platform::RUBY is the default platform (pure Ruby Gem).
  #
  module Platform
    RUBY = 'ruby'
    WIN32 = 'mswin32'
    LINUX_586 = 'i586-linux'
    DARWIN = 'powerpc-darwin'
    CURRENT = 'current'
  end
  
  # Potentially raised when a specification is validated.
  class InvalidSpecificationException < Gem::Exception; end
  class EndOfYAMLException < Gem::Exception; end

  # == Gem::Specification
  #
  # The Specification class contains the metadata for a Gem.  Typically defined in a
  # .gemspec file or a Rakefile, and looks like this:
  #
  #   spec = Gem::Specification.new do |s|
  #     s.name = 'rfoo'
  #     s.version = '1.0'
  #     s.summary = 'Example gem specification'
  #     ...
  #   end
  #
  # There are many <em>gemspec attributes</em>, and the best place to learn about them in
  # the "Gemspec Reference" linked from the RubyGems wiki.
  #
  class Specification

    # ------------------------- Specification version contstants.

    # The the version number of a specification that does not specify one (i.e. RubyGems 0.7
    # or earlier).
    NONEXISTENT_SPECIFICATION_VERSION = -1

    # The specification version applied to any new Specification instances created.  This
    # should be bumped whenever something in the spec format changes.
    CURRENT_SPECIFICATION_VERSION = 1

    # An informal list of changes to the specification.  The highest-valued key should be
    # equal to the CURRENT_SPECIFICATION_VERSION.
    SPECIFICATION_VERSION_HISTORY = {
      -1 => ['(RubyGems versions up to and including 0.7 did not have versioned specifications)'],
      1  => [
        'Deprecated "test_suite_file" in favor of the new, but equivalent, "test_files"',
        '"test_file=x" is a shortcut for "test_files=[x]"'
      ]
    }

    # ------------------------- Class variables.

    # List of Specification instances.
    @@list = []

    # Optional block used to gather newly defined instances.
    @@gather = nil

    # List of attribute names: [:name, :version, ...]
    @@required_attributes = []

    # List of _all_ attributes and default values: [[:name, nil], [:bindir, 'bin'], ...]
    @@attributes = []

    # List of array attributes
    @@array_attributes = []

    # Map of attribute names to default values.
    @@default_value = {}

    # ------------------------- Convenience class methods.

    def self.attribute_names
      @@attributes.map { |name, default| name }
    end

    def self.attribute_defaults
      @@attributes.dup
    end

    def self.default_value(name)
      @@default_value[name]
    end

    def self.required_attributes
      @@required_attributes.dup
    end

    def self.required_attribute?(name)
      @@required_attributes.include? name.to_sym
    end

    def self.array_attributes
      @@array_attributes.dup
    end

    # ------------------------- Infrastructure class methods.

    # A list of Specification instances that have been defined in this Ruby instance.
    def self.list
      @@list
    end

    # Used to specify the name and default value of a specification
    # attribute.  The side effects are:
    # * the name and default value are added to the @@attributes list
    #   and @@default_value map
    # * a standard _writer_ method (<tt>attribute=</tt>) is created
    # * a non-standard _reader method (<tt>attribute</tt>) is created
    #
    # The reader method behaves like this:
    #   def attribute
    #     @attribute ||= (copy of default value)
    #   end
    #
    # This allows lazy initialization of attributes to their default
    # values. 
    #
    def self.attribute(name, default=nil)
      @@attributes << [name, default]
      @@default_value[name] = default
      attr_accessor(name)
    end

    # Same as :attribute, but ensures that values assigned to the
    # attribute are array values by applying :to_a to the value.
    def self.array_attribute(name)
      @@array_attributes << name
      @@attributes << [name, []]
      @@default_value[name] = []
      module_eval %{
        def #{name}
          @#{name} ||= []
        end
        def #{name}=(value)
          @#{name} = value.to_a
        end
      }
    end

    # Same as attribute above, but also records this attribute as mandatory.
    def self.required_attribute(*args)
      @@required_attributes << args.first
      attribute(*args)
    end

    # Sometimes we don't want the world to use a setter method for a particular attribute.
    # +read_only+ makes it private so we can still use it internally.
    def self.read_only(*names)
      names.each do |name|
        private "#{name}="
      end
    end

    # Shortcut for creating several attributes at once (each with a default value of
    # +nil+).
    def self.attributes(*args)
      args.each do |arg|
        attribute(arg, nil)
      end
    end

    # Some attributes require special behaviour when they are accessed.  This allows for
    # that.
    def self.overwrite_accessor(name, &block)
      remove_method name
      define_method(name, &block)
    end

    # Defines a _singular_ version of an existing _plural_ attribute
    # (i.e. one whose value is expected to be an array).  This means
    # just creating a helper method that takes a single value and
    # appends it to the array.  These are created for convenience, so
    # that in a spec, one can write 
    #
    #   s.require_path = 'mylib'
    #
    # instead of
    #
    #   s.require_paths = ['mylib']
    #
    # That above convenience is available courtesy of
    #
    #   attribute_alias_singular :require_path, :require_paths 
    #
    def self.attribute_alias_singular(singular, plural)
      define_method("#{singular}=") { |val|
        send("#{plural}=", [val])
      }
      define_method("#{singular}") { 
        val = send("#{plural}")
        val.nil? ? nil : val.first
      }
    end

    def warn_deprecated(old, new)
      # How (if at all) to implement this?  We only want to warn when
      # a gem is being built, I should think.
    end
    
    # REQUIRED gemspec attributes ------------------------------------
    
    required_attribute :rubygems_version, RubyGemsVersion
    required_attribute :specification_version, CURRENT_SPECIFICATION_VERSION
    required_attribute :name
    required_attribute :version
    required_attribute :date
    required_attribute :summary
    required_attribute :require_paths, ['lib']
    
    read_only :specification_version

    # OPTIONAL gemspec attributes ------------------------------------
    
    attributes :email, :homepage, :rubyforge_project, :description
    attributes :autorequire, :default_executable
    attribute :bindir,                'bin'
    attribute :has_rdoc,               false
    attribute :required_ruby_version,  Gem::Version::Requirement.default
    attribute :platform,               Gem::Platform::RUBY

    attribute :signing_key,            nil
    attribute :cert_chain,             nil
    attribute :post_install_message,   nil

    array_attribute :authors
    array_attribute :files
    array_attribute :test_files
    array_attribute :rdoc_options
    array_attribute :extra_rdoc_files
    array_attribute :executables
    array_attribute :extensions
    array_attribute :requirements
    array_attribute :dependencies

    read_only :dependencies

    # ALIASED gemspec attributes -------------------------------------
    
    attribute_alias_singular :executable,   :executables
    attribute_alias_singular :author,   :authors
    attribute_alias_singular :require_path, :require_paths
    attribute_alias_singular :test_file,    :test_files

    # DEPRECATED gemspec attributes ----------------------------------
    
    def test_suite_file
      warn_deprecated(:test_suite_file, :test_files)
      test_files.first
    end

    def test_suite_file=(val)
      warn_deprecated(:test_suite_file, :test_files)
      @test_files = [] unless defined? @test_files
      @test_files << val
    end
 
    # RUNTIME attributes (not persisted) -----------------------------
    
    attr_writer :loaded
    attr_accessor :loaded_from

    # Special accessor behaviours (overwriting default) --------------
    
    overwrite_accessor :version= do |version|
      @version = Version.create(version)
    end

    overwrite_accessor :platform= do |platform|
      # Checks the provided platform for the special value
      # Platform::CURRENT and changes it to be binary specific to the
      # current platform (i386-mswin32, etc). 
      @platform = (platform == Platform::CURRENT ? RUBY_PLATFORM : platform)
    end

    overwrite_accessor :required_ruby_version= do |value|
      @required_ruby_version = Version::Requirement.create(value)
    end

    overwrite_accessor :date= do |date|
      # We want to end up with a Time object with one-day resolution.
      # This is the cleanest, most-readable, faster-than-using-Date
      # way to do it. 
      case date
      when String then
        @date = Time.parse date
      when Time then
        @date = Time.parse date.strftime("%Y-%m-%d")
      when Date then
        @date = Time.parse date.to_s
      else
        @date = Time.today
      end
    end

    overwrite_accessor :date do
      self.date = nil if @date.nil?  # HACK Sets the default value for date
      @date
    end

    overwrite_accessor :summary= do |str|
      @summary = if str then
                   str.strip.
                   gsub(/(\w-)\n[ \t]*(\w)/, '\1\2').
                   gsub(/\n[ \t]*/, " ")
                 end
    end

    overwrite_accessor :description= do |str|
      @description = if str then
                       str.strip.
                       gsub(/(\w-)\n[ \t]*(\w)/, '\1\2').
                       gsub(/\n[ \t]*/, " ")
                     end
    end

    overwrite_accessor :default_executable do
      begin
        if defined? @default_executable and @default_executable
          result = @default_executable 
        elsif @executables and @executables.size == 1
          result = @executables.first
        else
          result = nil
        end
        result
      rescue
        nil
      end
    end

    def add_bindir(executables)
      if not defined? @executables || @executables.nil?
        return nil
      end

      if defined? @bindir and @bindir then
        @executables.map {|e| File.join(@bindir, e) }
      else
        @executables
      end
    rescue
      return nil
    end

    overwrite_accessor :files do
      result = []
      result |= as_array(@files) if defined?(@files)
      result |= as_array(@test_files) if defined?(@test_files)
      result |= as_array(add_bindir(@executables) || [])
      result |= as_array(@extra_rdoc_files) if defined?(@extra_rdoc_files)
      result |= as_array(@extensions) if defined?(@extensions)
      result
    end

    overwrite_accessor :test_files do
      # Handle the possibility that we have @test_suite_file but not
      # @test_files.  This will happen when an old gem is loaded via
      # YAML.
      if defined? @test_suite_file then
        @test_files = [@test_suite_file].flatten
        @test_suite_file = nil
      end
      if defined? @test_files and @test_files then
        @test_files
      else
        @test_files = []
      end
    end

    # Predicates -----------------------------------------------------
    
    def loaded?; @loaded ? true : false ; end
    def has_rdoc?; has_rdoc ? true : false ; end
    def has_unit_tests?; not test_files.empty?; end
    alias has_test_suite? has_unit_tests?               # (deprecated)
    
    # Constructors ---------------------------------------------------
    
    # Specification constructor.  Assigns the default values to the
    # attributes, adds this spec to the list of loaded specs (see
    # Specification.list), and yields itself for further initialization.
    #
    def initialize
      # Each attribute has a default value (possibly nil).  Here, we
      # initialize all attributes to their default value.  This is
      # done through the accessor methods, so special behaviours will
      # be honored.  Furthermore, we take a _copy_ of the default so
      # each specification instance has its own empty arrays, etc.
      @@attributes.each do |name, default|
        if RUBY_VERSION >= "1.9" then
          self.funcall "#{name}=", copy_of(default)
        else
          self.send "#{name}=", copy_of(default)
        end
      end
      @loaded = false
      @@list << self
      yield self if block_given?
      @@gather.call(self) if @@gather
    end

    # Special loader for YAML files.  When a Specification object is
    # loaded from a YAML file, it bypasses the normal Ruby object
    # initialization routine (#initialize).  This method makes up for
    # that and deals with gems of different ages.
    #
    # 'input' can be anything that YAML.load() accepts: String or IO. 
    #
    def Specification.from_yaml(input)
      input = normalize_yaml_input(input)
      spec = YAML.load(input)
      if(spec && spec.class == FalseClass) then
        raise Gem::EndOfYAMLException
      end
      unless Specification === spec
        raise Gem::Exception, "YAML data doesn't evaluate to gem specification"
      end
      unless spec.instance_variables.include? '@specification_version' and
             spec.instance_variable_get :@specification_version
        spec.instance_variable_set :@specification_version, 
          NONEXISTENT_SPECIFICATION_VERSION
      end
      spec
    end 

    def Specification.load(filename)
      gemspec = nil
      fail "NESTED Specification.load calls not allowed!" if @@gather
      @@gather = proc { |gs| gemspec = gs }
      data = File.read(filename)
      eval(data)
      gemspec
    ensure
      @@gather = nil
    end

    # Make sure the yaml specification is properly formatted with dashes.
    def Specification.normalize_yaml_input(input)
      result = input.respond_to?(:read) ? input.read : input
      result = "--- " + result unless result =~ /^--- /
      result
    end
    
    # Instance methods -----------------------------------------------
    
    # Sets the rubygems_version to Gem::RubyGemsVersion.
    #
    def mark_version
      @rubygems_version = RubyGemsVersion
    end

    # Adds a dependency to this Gem.  For example,
    #
    #   spec.add_dependency('jabber4r', '> 0.1', '<= 0.5')
    #
    # gem:: [String or Gem::Dependency] The Gem name/dependency.
    # requirements:: [default="> 0.0.0"] The version requirements.   
    #
    def add_dependency(gem, *requirements)
      requirements = ['> 0.0.0'] if requirements.empty?
      requirements.flatten!
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirements)
        gem = Dependency.new(gem, requirements)
      end
      dependencies << gem
    end
    
    # Returns the full name (name-version) of this Gem.  Platform information
    # is included (name-version-platform) if it is specified (and not the
    # default Ruby platform).
    #
    def full_name
      if platform == Gem::Platform::RUBY || platform.nil?
        "#{@name}-#{@version}"
      else
        "#{@name}-#{@version}-#{platform}"
      end 
    end
    
    # The full path to the gem (install path + full name).
    #
    # return:: [String] the full gem path
    #
    def full_gem_path
      File.join(installation_path, "gems", full_name)
    end
    
    # The default (generated) file name of the gem.
    def file_name
      full_name + ".gem"
    end
    
    # The root directory that the gem was installed into.
    #
    # return:: [String] the installation path
    #
    def installation_path
      (File.dirname(@loaded_from).split(File::SEPARATOR)[0..-2]).
        join(File::SEPARATOR)
    end
    
    # Checks if this Specification meets the requirement of the supplied
    # dependency.
    # 
    # dependency:: [Gem::Dependency] the dependency to check
    # return:: [Boolean] true if dependency is met, otherwise false
    #
    def satisfies_requirement?(dependency)
      return @name == dependency.name && 
        dependency.version_requirements.satisfied_by?(@version)
    end
    
    # Comparison methods ---------------------------------------------
    
    # Compare specs (name then version).
    def <=>(other)
      [@name, @version] <=> [other.name, other.version]
    end

    # Tests specs for equality (across all attributes).
    def ==(other) # :nodoc:
      other.kind_of?(self.class) && same_attributes?(other)
    end

    alias eql? == # :nodoc:

    def same_attributes?(other)
      @@attributes.each do |name, default|
        return false unless self.send(name) == other.send(name)
      end
      true
    end
    private :same_attributes?

    def hash # :nodoc:
      @@attributes.inject(0) { |hash_code, (name, default_value)|
        n = self.send(name).hash
        hash_code + n
      }
    end
    
    # Export methods (YAML and Ruby code) ----------------------------
    
    # Returns an array of attribute names to be used when generating a
    # YAML representation of this object.  If an attribute still has
    # its default value, it is omitted.
    def to_yaml_properties
      mark_version
      @@attributes.map { |name, default| "@#{name}" }
    end

    # Returns a Ruby code representation of this specification, such
    # that it can be eval'ed and reconstruct the same specification
    # later.  Attributes that still have their default values are
    # omitted.
    def to_ruby
      mark_version
      result = "Gem::Specification.new do |s|\n"
      @@attributes.each do |name, default|
        # TODO better implementation of next line (read_only_attribute? ... something like that)
        next if name == :dependencies or name == :specification_version
        current_value = self.send(name)
        result << "  s.#{name} = #{ruby_code(current_value)}\n" unless current_value == default
      end
      dependencies.each do |dep|
        version_reqs_param = dep.requirements_list.inspect
        result << "  s.add_dependency(%q<#{dep.name}>, #{version_reqs_param})\n"
      end
      result << "end\n"
    end

    # Validation and normalization methods ---------------------------
    
    # Checks that the specification contains all required fields, and
    # does a very basic sanity check.
    #
    # Raises InvalidSpecificationException if the spec does not pass
    # the checks..
    def validate
      normalize
      if rubygems_version != RubyGemsVersion
        raise InvalidSpecificationException.new(%[
          Expected RubyGems Version #{RubyGemsVersion}, was #{rubygems_version}
        ].strip)
      end
      @@required_attributes.each do |symbol|
        unless self.send(symbol)
          raise InvalidSpecificationException.new("Missing value for attribute #{symbol}")
        end
      end 
      if require_paths.empty?
        raise InvalidSpecificationException.new("Gem spec needs to have at least one require_path")
      end
    end

    # Normalize the list of files so that:
    # * All file lists have redundancies removed.
    # * Files referenced in the extra_rdoc_files are included in the
    #   package file list. 
    #
    # Also, the summary and description are converted to a normal
    # format. 
    def normalize
      if defined? @extra_rdoc_files and @extra_rdoc_files then
        @extra_rdoc_files.uniq!
        @files ||= []
        @files.concat(@extra_rdoc_files)
      end
      @files.uniq! if @files
    end

    # Dependency methods ---------------------------------------------
    
    # Return a list of all gems that have a dependency on this
    # gemspec.  The list is structured with entries that conform to:
    #
    #   [depending_gem, dependency, [list_of_gems_that_satisfy_dependency]]
    #
    # return:: [Array] [[dependent_gem, dependency, [list_of_satisfiers]]]
    #
    def dependent_gems
      out = []
      Gem.source_index.each do |name,gem|
        gem.dependencies.each do |dep|
          if self.satisfies_requirement?(dep) then
            sats = []
            find_all_satisfiers(dep) do |sat|
              sats << sat
            end
            out << [gem, dep, sats]
          end
        end
      end
      out
    end

    def to_s
      "#<Gem::Specification name=#{@name} version=#{@version}>"
    end

    private

    def find_all_satisfiers(dep)
      Gem.source_index.each do |name,gem|
        if(gem.satisfies_requirement?(dep)) then
          yield gem
        end
      end
    end

    # Duplicate an object unless it's an immediate value.
    def copy_of(obj)
      case obj
      when Numeric, Symbol, true, false, nil then obj
      else obj.dup
      end
    end

    def as_array(items)
      items.to_ary
    rescue NoMethodError => ex
      [items]
    end

    # Return a string containing a Ruby code representation of the
    # given object.
    def ruby_code(obj)
      case obj
      when String           then '%q{' + obj + '}'
      when Array            then obj.inspect
      when Gem::Version     then obj.to_s.inspect
      when Date, Time       then '%q{' + obj.strftime('%Y-%m-%d') + '}'
      when Numeric          then obj.inspect
      when true, false, nil then obj.inspect
      when Gem::Version::Requirement  then "Gem::Version::Requirement.new(#{obj.to_s.inspect})"
      else raise Exception, "ruby_code case not handled: #{obj.class}"
      end
    end

  end

end

