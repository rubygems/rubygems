require 'delegate'
class Gem::SpecificationPolicy < SimpleDelegator
  VALID_NAME_PATTERN = /\A[a-zA-Z0-9\.\-\_]+\z/ # :nodoc:

  attr_accessor :packaging

  def call
    validate_nil_attributes

    validate_rubygems_version

    validate_required_attributes

    validate_name

    validate_require_paths

    normalize_files

    validate_non_files

    validate_self_inclusion_in_files_list

    validate_specification_version

    validate_platform

    validate_array_attributes

    validate_authors_field

    validate_metadata

    validate_licenses

    validate_permissions

    validate_lazy_metadata

    validate_values

    validate_dependencies
    true
  end

  def validate_metadata
    unless Hash === metadata then
      raise Gem::InvalidSpecificationException,
            'metadata must be a hash'
    end

    url_validation_regex = %r{\Ahttps?:\/\/([^\s:@]+:[^\s:@]*@)?[A-Za-z\d\-]+(\.[A-Za-z\d\-]+)+\.?(:\d{1,5})?([\/?]\S*)?\z}
    link_keys = %w[
      bug_tracker_uri
      changelog_uri
      documentation_uri
      homepage_uri
      mailing_list_uri
      source_code_uri
      wiki_uri
    ]

    metadata.each do|key, value|
      if !key.kind_of?(String) then
        raise Gem::InvalidSpecificationException,
              "metadata keys must be a String"
      end

      if key.size > 128 then
        raise Gem::InvalidSpecificationException,
              "metadata key too large (#{key.size} > 128)"
      end

      if !value.kind_of?(String) then
        raise Gem::InvalidSpecificationException,
              "metadata values must be a String"
      end

      if value.size > 1024 then
        raise Gem::InvalidSpecificationException,
              "metadata value too large (#{value.size} > 1024)"
      end

      if link_keys.include? key then
        if value !~ url_validation_regex then
          raise Gem::InvalidSpecificationException,
                "metadata['#{key}'] has invalid link: #{value.inspect}"
        end
      end
    end
  end

  ##
  # Checks that dependencies use requirements as we recommend.  Warnings are
  # issued when dependencies are open-ended or overly strict for semantic
  # versioning.
  def validate_dependencies # :nodoc:
    # NOTE: see REFACTOR note in Gem::Dependency about types - this might be brittle
    seen = Gem::Dependency::TYPES.inject({}) { |types, type| types.merge({ type => {}}) }

    error_messages = []
    warning_messages = []
    dependencies.each do |dep|
      if prev = seen[dep.type][dep.name] then
        error_messages << <<-MESSAGE
duplicate dependency on #{dep}, (#{prev.requirement}) use:
    add_#{dep.type}_dependency '#{dep.name}', '#{dep.requirement}', '#{prev.requirement}'
        MESSAGE
      end

      seen[dep.type][dep.name] = dep

      prerelease_dep = dep.requirements_list.any? do |req|
        Gem::Requirement.new(req).prerelease?
      end

      warning_messages << "prerelease dependency on #{dep} is not recommended" if
          prerelease_dep && !version.prerelease?

      overly_strict = dep.requirement.requirements.length == 1 &&
          dep.requirement.requirements.any? do |op, version|
            op == '~>' and
                not version.prerelease? and
                version.segments.length > 2 and
                version.segments.first != 0
          end

      if overly_strict then
        _, dep_version = dep.requirement.requirements.first

        base = dep_version.segments.first 2

        warning_messages << <<-WARNING
pessimistic dependency on #{dep} may be overly strict
  if #{dep.name} is semantically versioned, use:
    add_#{dep.type}_dependency '#{dep.name}', '~> #{base.join '.'}', '>= #{dep_version}'
        WARNING
      end

      open_ended = dep.requirement.requirements.all? do |op, version|
        not version.prerelease? and (op == '>' or op == '>=')
      end

      if open_ended then
        op, dep_version = dep.requirement.requirements.first

        base = dep_version.segments.first 2

        bugfix = if op == '>' then
                   ", '> #{dep_version}'"
                 elsif op == '>=' and base != dep_version.segments then
                   ", '>= #{dep_version}'"
                 end

        warning_messages << <<-WARNING
open-ended dependency on #{dep} is not recommended
  if #{dep.name} is semantically versioned, use:
    add_#{dep.type}_dependency '#{dep.name}', '~> #{base.join '.'}'#{bugfix}
        WARNING
      end
    end
    if error_messages.any? then
      raise Gem::InvalidSpecificationException, error_messages.join
    end
    if warning_messages.any? then
      warning_messages.each { |warning_message| warning warning_message }
    end
  end

  ##
  # Checks to see if the files to be packaged are world-readable.
  def validate_permissions
    return if Gem.win_platform?

    files.each do |file|
      next unless File.file?(file)
      next if File.stat(file).mode & 0444 == 0444
      warning "#{file} is not world-readable"
    end

    executables.each do |name|
      exec = File.join bindir, name
      next unless File.file?(exec)
      next if File.stat(exec).executable?
      warning "#{exec} is not executable"
    end
  end

  private

  def validate_nil_attributes
    nil_attributes = __getobj__.class.non_nil_attributes.select do |attrname|
      __getobj__.instance_variable_get("@#{attrname}").nil?
    end
    return if nil_attributes.empty?
    raise Gem::InvalidSpecificationException,
          "#{nil_attributes.join ', '} must not be nil"
  end

  def validate_rubygems_version
    if packaging && rubygems_version != Gem::VERSION then
      raise Gem::InvalidSpecificationException,
            "expected RubyGems version #{Gem::VERSION}, was #{rubygems_version}"
    end
  end

  def validate_required_attributes
    __getobj__.class.required_attributes.each do |symbol|
      unless send symbol then
        raise Gem::InvalidSpecificationException,
              "missing value for attribute #{symbol}"
      end
    end
  end

  def validate_name
    if !name.is_a?(String) then
      raise Gem::InvalidSpecificationException,
            "invalid value for attribute name: \"#{name.inspect}\" must be a string"
    elsif name !~ /[a-zA-Z]/ then
      raise Gem::InvalidSpecificationException,
            "invalid value for attribute name: #{name.dump} must include at least one letter"
    elsif name !~ VALID_NAME_PATTERN then
      raise Gem::InvalidSpecificationException,
            "invalid value for attribute name: #{name.dump} can only include letters, numbers, dashes, and underscores"
    end
  end

  def validate_require_paths
    if raw_require_paths.empty? then
      raise Gem::InvalidSpecificationException,
            'specification must have at least one require_path'
    end
  end

  def validate_non_files
    non_files = files.reject {|x| File.file?(x) || File.symlink?(x)}

    unless not packaging or non_files.empty? then
      raise Gem::InvalidSpecificationException,
            "[\"#{non_files.join "\", \""}\"] are not files"
    end
  end

  def validate_self_inclusion_in_files_list
    return unless files.include?(file_name)
    
    raise Gem::InvalidSpecificationException,
          "#{full_name} contains itself (#{file_name}), check your files list"
  end

  def validate_specification_version
    return if specification_version.is_a?(Integer)
    
    raise Gem::InvalidSpecificationException,
          'specification_version must be an Integer (did you mean version?)'
  end

  def validate_platform
    case platform
      when Gem::Platform, Gem::Platform::RUBY then # ok
      else
        raise Gem::InvalidSpecificationException,
              "invalid platform #{platform.inspect}, see Gem::Platform"
    end
  end

  def validate_array_attributes
    __getobj__.class.array_attributes.each do |field|
      val = self.send(field)
      klass = case field
                when :dependencies then
                  Gem::Dependency
                else
                  String
              end

      unless Array === val and val.all? {|x| x.kind_of?(klass)} then
        raise(Gem::InvalidSpecificationException,
              "#{field} must be an Array of #{klass}")
      end
    end
  end

  def validate_authors_field
    return unless authors.empty?

    raise Gem::InvalidSpecificationException,
          "authors may not be empty"
  end

  def validate_licenses
    licenses.each { |license|
      if license.length > 64 then
        raise Gem::InvalidSpecificationException,
              "each license must be 64 characters or less"
      end

      if !Gem::Licenses.match?(license) then
        suggestions = Gem::Licenses.suggestions(license)
        message = <<-warning
license value '#{license}' is invalid.  Use a license identifier from
http://spdx.org/licenses or '#{Gem::Licenses::NONSTANDARD}' for a nonstandard license.
        warning
        message += "Did you mean #{suggestions.map { |s| "'#{s}'"}.join(', ')}?\n" unless suggestions.nil?
        warning(message)
      end
    }

    warning <<-warning if licenses.empty?
licenses is empty, but is recommended.  Use a license identifier from
http://spdx.org/licenses or '#{Gem::Licenses::NONSTANDARD}' for a nonstandard license.
    warning
  end

  def validate_lazy_metadata
    lazy = '"FIxxxXME" or "TOxxxDO"'.gsub(/xxx/, '')
    lazy_pattern = /FI XME|TO DO/x

    unless authors.grep(lazy_pattern).empty? then
      raise Gem::InvalidSpecificationException, "#{lazy} is not an author"
    end

    unless Array(email).grep(lazy_pattern).empty? then
      raise Gem::InvalidSpecificationException, "#{lazy} is not an email"
    end

    if description =~ lazy_pattern then
      raise Gem::InvalidSpecificationException, "#{lazy} is not a description"
    end

    if summary =~ lazy_pattern then
      raise Gem::InvalidSpecificationException, "#{lazy} is not a summary"
    end

    if homepage and not homepage.empty? and
        homepage !~ /\A[a-z][a-z\d+.-]*:/i then
      raise Gem::InvalidSpecificationException,
            "\"#{homepage}\" is not a URI"
    end
  end

  def validate_values
    %w[author homepage summary files].each do |attribute|
      value = self.send attribute
      warning("no #{attribute} specified") if value.nil? || value.empty?
    end

    if description == summary then
      warning "description and summary are identical"
    end

    # TODO: raise at some given date
    warning "deprecated autorequire specified" if autorequire

    executables.each do |executable|
      executable_path = File.join(bindir, executable)
      shebang = File.read(executable_path, 2) == '#!'

      warning "#{executable_path} is missing #! line" unless shebang
    end

    files.select { |f| File.symlink?(f) }.each do |file|
      warning "#{file} is a symlink, which is not supported on all platforms"
    end
  end
end

