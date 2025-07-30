#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"
require "json"
require "fileutils"
require "tmpdir"

class DeserializationValidator
  def initialize(test_data_dir, version_info)
    @test_data_dir = test_data_dir
    @version_info = version_info
    @failures = []
    @successes = []

    load_metadata
  end

  def validate_all
    puts "Validating deserialization compatibility..."
    puts "Test data directory: #{@test_data_dir}"
    puts "Current Ruby version: #{RUBY_VERSION}"
    puts "Current RubyGems version: #{Gem::VERSION}"
    puts "Testing against version: #{@version_info}"
    puts "Original data generated with: #{@metadata&.dig("rubygems_version") || "unknown"}"
    puts "Original Ruby version: #{@metadata&.dig("ruby_version") || "unknown"}"
    puts

    validate_gemspecs
    validate_marshal_indexes
    validate_nametuple_indexes
    validate_safe_marshal

    report_results
    exit(@failures.empty? ? 0 : 1)
  end

  private

  def load_metadata
    metadata_file = File.join(@test_data_dir, "metadata.json")
    if File.exist?(metadata_file)
      @metadata = JSON.parse(File.read(metadata_file))
    else
      puts "WARNING: No metadata file found at #{metadata_file}"
      @metadata = {}
    end
  end

  def validate_gemspecs
    puts "=== Validating Gemspec Deserialization ==="

    gemspec_dir = File.join(@test_data_dir, "gemspecs")
    return unless Dir.exist?(gemspec_dir)

    # Create temporary directory with stub files for validation
    Dir.mktmpdir do |temp_dir|
      create_stub_files(temp_dir)

      # Change to temp dir so gemspecs can find their files
      Dir.chdir(temp_dir) do
        Dir.glob("*.marshal", base: gemspec_dir).each do |marshal_file|
          test_name = File.basename(marshal_file, ".marshal")
          puts "Testing #{test_name}..."

          begin
            # Load marshaled gemspec
            marshal_path = File.join(gemspec_dir, marshal_file)
            marshaled_data = File.read(marshal_path, mode: "rb")

            # Load SafeMarshal if available
            Gem.load_safe_marshal if Gem.respond_to?(:load_safe_marshal)
            
            # Try to deserialize
            if defined?(Gem::SafeMarshal)
              # Use safe marshal if available (newer versions)
              spec = Gem::SafeMarshal.safe_load(marshaled_data)
            else
              # Fall back to regular Marshal (older versions)
              spec = Marshal.load(marshaled_data)
            end

            # Load expected data
            json_path = File.join(gemspec_dir, "#{test_name}.json")
            if File.exist?(json_path)
              expected = JSON.parse(File.read(json_path))
              validate_gemspec_attributes(spec, expected, test_name)
            else
              # Basic validation - just ensure it's a Gem::Specification
              if spec.is_a?(Gem::Specification)
                record_success("gemspec", test_name, "Successfully deserialized gemspec")
              else
                record_failure("gemspec", test_name, "Deserialized object is not a Gem::Specification: #{spec.class}")
              end
            end
          rescue StandardError => e
            error_details = "#{e.class}: #{e.message}"
            error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
            record_failure("gemspec", test_name, "Deserialization failed: #{error_details}")
          end
        end
      end
    end
  end

  def validate_gemspec_attributes(spec, expected, test_name)
    errors = []

    # Validate core attributes that should be preserved across serialization
    errors << {field: "name", expected: expected["name"], actual: spec.name} if spec.name != expected["name"]
    errors << {field: "version", expected: expected["version"], actual: spec.version.to_s} if spec.version.to_s != expected["version"]
    errors << {field: "summary", expected: expected["summary"], actual: spec.summary} if spec.summary != expected["summary"]

    # Validate platform
    errors << {field: "platform", expected: expected["platform"], actual: spec.platform.to_s} if spec.platform.to_s != expected["platform"]

    # Validate version requirements
    errors << {field: "required_ruby_version", expected: expected["required_ruby_version"], actual: spec.required_ruby_version.to_s} if spec.required_ruby_version.to_s != expected["required_ruby_version"]
    errors << {field: "required_rubygems_version", expected: expected["required_rubygems_version"], actual: spec.required_rubygems_version.to_s} if spec.required_rubygems_version.to_s != expected["required_rubygems_version"]

    # NOTE: We don't validate files list because RubyGems specifications reset the files
    # array during marshal deserialization (it gets filtered based on disk state).
    # This is the actual behavior we're testing for backwards compatibility.

    # Validate dependencies
    if expected["dependencies"] && !expected["dependencies"].empty?
      expected_deps = expected["dependencies"].map {|d| [d["name"], d["requirement"], d["type"].to_sym] }.sort
      actual_deps = spec.dependencies.map {|d| [d.name, d.requirement.to_s, d.type] }.sort
      errors << {field: "dependencies", expected: expected_deps, actual: actual_deps} if actual_deps != expected_deps
    end

    if errors.empty?
      record_success("gemspec", test_name, "All attributes validated successfully (#{spec.files.size} files, #{spec.dependencies.size} deps)")
    else
      errors.each do |error|
        record_failure("gemspec", test_name, error)
      end
    end
  end

  def validate_marshal_indexes
    puts "=== Validating Marshal Index Deserialization ==="

    index_dir = File.join(@test_data_dir, "marshal_indexes")
    return unless Dir.exist?(index_dir)

    Dir.glob("*.marshal", base: index_dir).each do |marshal_file|
      test_name = File.basename(marshal_file, ".marshal")
      puts "Testing #{test_name}..."

      begin
        # Load marshaled index data
        marshal_path = File.join(index_dir, marshal_file)
        marshaled_data = File.read(marshal_path, mode: "rb")

        # Try to deserialize
        if defined?(Bundler) && Bundler.respond_to?(:safe_load_marshal)
          # Use Bundler's safe marshal if available
          data = Bundler.safe_load_marshal(marshaled_data)
        else
          # Fall back to regular Marshal
          data = Marshal.load(marshaled_data)
        end

        # Load expected data
        json_path = File.join(index_dir, "#{test_name}.json")
        if File.exist?(json_path)
          expected = JSON.parse(File.read(json_path))
          validate_marshal_index_data(data, expected, test_name)
        else
          # Basic validation - ensure it's an array
          if data.is_a?(Array)
            record_success("marshal_index", test_name, "Successfully deserialized index data")
          else
            record_failure("marshal_index", test_name, "Deserialized object is not an Array: #{data.class}")
          end
        end
      rescue StandardError => e
        error_details = "#{e.class}: #{e.message}"
        error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
        record_failure("marshal_index", test_name, "Deserialization failed: #{error_details}")
      end
    end
  end

  def validate_marshal_index_data(data, expected, test_name)
    errors = []

    errors << "not an array" unless data.is_a?(Array)
    errors << {field: "array_size", expected: expected.size, actual: data.size} if data.size != expected.size

    # Validate each gem entry
    data.each_with_index do |gem_data, i|
      expected_gem = expected[i]
      next unless expected_gem

      if gem_data.is_a?(Hash)
        errors << {field: "gem[#{i}].name", expected: expected_gem["name"], actual: gem_data[:name]} if gem_data[:name] != expected_gem["name"]
        errors << {field: "gem[#{i}].version", expected: expected_gem["number"], actual: gem_data[:number]} if gem_data[:number] != expected_gem["number"]
        errors << {field: "gem[#{i}].platform", expected: expected_gem["platform"], actual: gem_data[:platform]} if gem_data[:platform] != expected_gem["platform"]
      else
        errors << "gem #{i} is not a hash: #{gem_data.class}"
      end
    end

    if errors.empty?
      record_success("marshal_index", test_name, "All index data validated successfully")
    else
      errors.each do |error|
        record_failure("marshal_index", test_name, error)
      end
    end
  end

  def validate_nametuple_indexes
    puts "=== Validating NameTuple Index Deserialization ==="

    # Load SafeMarshal if available
    Gem.load_safe_marshal if Gem.respond_to?(:load_safe_marshal)

    index_dir = File.join(@test_data_dir, "nametuple_indexes")
    return unless Dir.exist?(index_dir)

    # Test marshal files
    marshal_files = Dir.glob("*.marshal", base: index_dir)
    
    marshal_files.each do |marshal_file|
      test_name = File.basename(marshal_file, ".marshal")
      puts "Testing #{test_name}..."

      begin
        # Load marshaled spec tuple data
        marshal_path = File.join(index_dir, marshal_file)
        marshaled_data = File.read(marshal_path, mode: "rb")

        # Try to deserialize using SafeMarshal if available, otherwise regular Marshal
        spec_tuples = if defined?(Gem::SafeMarshal)
          Gem::SafeMarshal.safe_load(marshaled_data)
        else
          Marshal.load(marshaled_data)
        end

        # Test the actual NameTuple.from_list pattern used by Gem::Source#load_specs
        name_tuples = if defined?(Gem::NameTuple)
          Gem::NameTuple.from_list(spec_tuples)
        else
          # Fallback for older RubyGems versions
          spec_tuples.map { |name, version, platform| [name, version, platform] }
        end

        # Load expected data for validation
        json_path = File.join(index_dir, "#{test_name}.json")
        if File.exist?(json_path)
          expected = JSON.parse(File.read(json_path))
          validate_nametuple_data(name_tuples, expected, test_name)
        else
          # Basic validation - ensure it's an array
          if name_tuples.is_a?(Array) && !name_tuples.empty?
            record_success("nametuple_index", test_name, "Successfully created #{name_tuples.size} NameTuples")
          else
            record_failure("nametuple_index", test_name, {field: "result", expected: "Array of NameTuples", actual: name_tuples.class.name})
          end
        end
      rescue StandardError => e
        error_details = "#{e.class}: #{e.message}"
        error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
        record_failure("nametuple_index", test_name, "NameTuple loading failed: #{error_details}")
      end
    end
  end

  def validate_nametuple_data(name_tuples, expected, test_name)
    errors = []

    # Validate array structure
    errors << {field: "type", expected: "Array", actual: name_tuples.class.name} unless name_tuples.is_a?(Array)
    errors << {field: "size", expected: expected.size, actual: name_tuples.size} if name_tuples.size != expected.size

    # Validate each NameTuple
    name_tuples.each_with_index do |name_tuple, i|
      expected_tuple = expected[i]
      next unless expected_tuple

      if defined?(Gem::NameTuple) && name_tuple.is_a?(Gem::NameTuple)
        # Test NameTuple object
        errors << {field: "tuple[#{i}].name", expected: expected_tuple["name"], actual: name_tuple.name} if name_tuple.name != expected_tuple["name"]
        errors << {field: "tuple[#{i}].version", expected: expected_tuple["version"], actual: name_tuple.version.to_s} if name_tuple.version.to_s != expected_tuple["version"]
        errors << {field: "tuple[#{i}].platform", expected: expected_tuple["platform"], actual: name_tuple.platform.to_s} if name_tuple.platform.to_s != expected_tuple["platform"]
      elsif name_tuple.is_a?(Array) && name_tuple.size == 3
        # Test raw array format
        name, version, platform = name_tuple
        errors << {field: "tuple[#{i}].name", expected: expected_tuple["name"], actual: name} if name != expected_tuple["name"]
        errors << {field: "tuple[#{i}].version", expected: expected_tuple["version"], actual: version.to_s} if version.to_s != expected_tuple["version"]
        errors << {field: "tuple[#{i}].platform", expected: expected_tuple["platform"], actual: platform.to_s} if platform.to_s != expected_tuple["platform"]
      else
        errors << {field: "tuple[#{i}].format", expected: "NameTuple or [name, version, platform]", actual: name_tuple.class.name}
      end
    end

    if errors.empty?
      record_success("nametuple_index", test_name, "All NameTuple data validated successfully (#{name_tuples.size} tuples)")
    else
      errors.each do |error|
        record_failure("nametuple_index", test_name, error)
      end
    end
  end

  def validate_safe_marshal
    puts "=== Validating Safe Marshal Deserialization ==="

    marshal_dir = File.join(@test_data_dir, "safe_marshal")
    return unless Dir.exist?(marshal_dir)

    Dir.glob("*.marshal", base: marshal_dir).each do |marshal_file|
      test_name = File.basename(marshal_file, ".marshal")
      puts "Testing #{test_name}..."

      begin
        # Load marshaled data
        marshal_path = File.join(marshal_dir, marshal_file)
        marshaled_data = File.read(marshal_path, mode: "rb")

        # Load SafeMarshal if available  
        Gem.load_safe_marshal if Gem.respond_to?(:load_safe_marshal)
        
        # Try to deserialize
        if defined?(Gem::SafeMarshal)
          object = Gem::SafeMarshal.safe_load(marshaled_data)
        else
          object = Marshal.load(marshaled_data)
        end

        # Load expected data
        json_path = File.join(marshal_dir, "#{test_name}.json")
        if File.exist?(json_path)
          expected = JSON.parse(File.read(json_path))
          validate_safe_marshal_object(object, expected, test_name)
        else
          record_success("safe_marshal", test_name, "Successfully deserialized object: #{object.class}")
        end
      rescue StandardError => e
        error_details = "#{e.class}: #{e.message}"
        error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
        record_failure("safe_marshal", test_name, "Deserialization failed: #{error_details}")
      end
    end
  end

  def validate_safe_marshal_object(object, expected, test_name)
    errors = []

    # Check class
    errors << {field: "class", expected: expected["class"], actual: object.class.name} if object.class.name != expected["class"]

    # Check string representations (if they should be stable)
    # Skip for Time and Hash objects which have different string representations across Ruby versions
    unless expected["class"] == "Time" || expected["class"] == "Hash"
      errors << {field: "to_s", expected: expected["to_s"], actual: object.to_s} if object.to_s != expected["to_s"]
    end

    # Type-specific validations
    case object
    when Gem::Version
      errors << {field: "version", expected: expected["version"], actual: object.version} if object.version != expected["version"]
    when Gem::Dependency
      errors << {field: "name", expected: expected["name"], actual: object.name} if object.name != expected["name"]
      errors << {field: "requirement", expected: expected["requirement"], actual: object.requirement.to_s} if object.requirement.to_s != expected["requirement"]
      errors << {field: "type", expected: expected["type"], actual: object.type.to_s} if object.type != expected["type"].to_sym
    when Hash
      errors << {field: "size", expected: expected["size"], actual: object.size} if object.size != expected["size"]
    when Array
      errors << {field: "size", expected: expected["size"], actual: object.size} if object.size != expected["size"]
    end

    if errors.empty?
      record_success("safe_marshal", test_name, "Object validated successfully")
    else
      errors.each do |error|
        record_failure("safe_marshal", test_name, error)
      end
    end
  end

  def record_success(category, test_name, message)
    @successes << { category: category, test: test_name, message: message }
    puts "  ✓ #{message}"
  end

  def record_failure(category, test_name, message)
    @failures << { category: category, test: test_name, message: message }
    if message.is_a?(Hash) && message[:field]
      puts "  ✗ Field '#{message[:field]}' mismatch:"
      puts "    Expected: #{format_value(message[:expected])}"
      puts "    Actual:   #{format_value(message[:actual])}"
      if message[:expected].is_a?(String) && message[:actual].is_a?(String)
        show_string_diff(message[:expected], message[:actual])
      end
    else
      puts "  ✗ #{message}"
    end
  end

  def format_value(value)
    case value
    when String
      if value.length > 100
        "#{value[0..50]}...#{value[-47..-1]} (#{value.length} chars)"
      else
        value.inspect
      end
    when Array
      if value.length > 5
        "[#{value[0..2].map(&:inspect).join(", ")}, ... (#{value.length} total)]"
      else
        value.inspect
      end
    when Hash
      if value.size > 3
        keys = value.keys[0..2].map(&:inspect).join(", ")
        "{#{keys}, ... (#{value.size} keys)}"
      else
        value.inspect
      end
    else
      value.inspect
    end
  end

  def show_string_diff(expected, actual)
    # Find first difference
    min_length = [expected.length, actual.length].min
    first_diff = nil
    
    (0...min_length).each do |i|
      if expected[i] != actual[i]
        first_diff = i
        break
      end
    end
    
    if first_diff
      # Show context around the difference
      start_pos = [first_diff - 20, 0].max
      end_pos = [first_diff + 20, min_length].min
      
      puts "    Diff at position #{first_diff}:"
      puts "    Expected: ...#{expected[start_pos...end_pos].inspect}..."
      puts "    Actual:   ...#{actual[start_pos...end_pos].inspect}..."
    elsif expected.length != actual.length
      puts "    Length difference: expected #{expected.length}, actual #{actual.length}"
    end
  end

  def create_stub_files(base_dir)
    # Create lib directory and files
    lib_dir = File.join(base_dir, "lib")
    FileUtils.mkdir_p(lib_dir)

    File.write(File.join(lib_dir, "test.rb"), "# Test gem main file\nmodule TestGem\n  VERSION = '1.0.0'\nend\n")
    File.write(File.join(lib_dir, "complex.rb"), "# Complex gem main file\nmodule ComplexGem\n  VERSION = '2.1.3'\nend\n")
    File.write(File.join(lib_dir, "dep.rb"), "# Dependency gem main file\nmodule DepGem\n  VERSION = '1.5.0'\nend\n")
    File.write(File.join(lib_dir, "native.rb"), "# Native gem Ruby wrapper\nmodule NativeGem\n  VERSION = '0.9.0'\nend\n")

    # Create bin directory and executables
    bin_dir = File.join(base_dir, "bin")
    FileUtils.mkdir_p(bin_dir)

    executable_content = "#!/usr/bin/env ruby\n# Complex tool executable\nputs 'Hello from complex-tool'\n"
    File.write(File.join(bin_dir, "complex-tool"), executable_content)
    File.chmod(0o755, File.join(bin_dir, "complex-tool"))

    # Create ext directory and native extension files
    ext_dir = File.join(base_dir, "ext", "native")
    FileUtils.mkdir_p(ext_dir)

    extconf_rb = <<~RUBY
      require 'mkmf'

      create_makefile('native')
    RUBY
    File.write(File.join(ext_dir, "extconf.rb"), extconf_rb)

    native_c = <<~C
      #include <ruby.h>

      VALUE rb_mNative;

      void Init_native() {
          rb_mNative = rb_define_module("Native");
      }
    C
    File.write(File.join(ext_dir, "native.c"), native_c)

    # Create documentation files
    File.write(File.join(base_dir, "README.md"), "# Test Gem\n\nThis is a test gem for compatibility testing.\n")
    File.write(File.join(base_dir, "LICENSE"), "MIT License\n\nCopyright (c) 2024 Test Authors\n")
    File.write(File.join(base_dir, "CHANGELOG.md"), "# Changelog\n\n## [1.0.0] - 2024-01-01\n- Initial release\n")
  end

  def report_results
    puts "\n" + "=" * 50
    puts "VALIDATION RESULTS"
    puts "=" * 50

    puts "Successes: #{@successes.size}"
    puts "Failures: #{@failures.size}"

    if @failures.any?
      puts "\nFAILURES:"
      @failures.each do |failure|
        puts "  [#{failure[:category]}] #{failure[:test]}: #{failure[:message]}"
      end
    end

    puts "\nSUCCESSES:"
    @successes.group_by {|s| s[:category] }.each do |category, successes|
      puts "  #{category}: #{successes.size} tests passed"
    end
  end
end

# Main execution
if ARGV.length != 2
  puts "Usage: #{$0} <test_data_dir> <version_info>"
  puts "  test_data_dir: directory containing test data"
  puts "  version_info: version information for reporting"
  exit 1
end

test_data_dir, version_info = ARGV
validator = DeserializationValidator.new(test_data_dir, version_info)
validator.validate_all
