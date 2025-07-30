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
    puts "Current RubyGems version: #{Gem::VERSION}"
    puts "Testing against version: #{@version_info}"
    puts "Original data generated with: #{@metadata&.dig("rubygems_version") || "unknown"}"
    puts

    validate_gemspecs
    validate_marshal_indexes
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
            record_failure("gemspec", test_name, "Deserialization failed: #{e.message}")
          end
        end
      end
    end
  end

  def validate_gemspec_attributes(spec, expected, test_name)
    errors = []

    # Validate core attributes that should be preserved across serialization
    errors << "name mismatch: expected '#{expected["name"]}', got '#{spec.name}'" if spec.name != expected["name"]
    errors << "version mismatch: expected '#{expected["version"]}', got '#{spec.version}'" if spec.version.to_s != expected["version"]
    errors << "summary mismatch: expected '#{expected["summary"]}', got '#{spec.summary}'" if spec.summary != expected["summary"]

    # Validate platform
    errors << "platform mismatch: expected '#{expected["platform"]}', got '#{spec.platform}'" if spec.platform.to_s != expected["platform"]

    # Validate version requirements
    errors << "required_ruby_version mismatch" if spec.required_ruby_version.to_s != expected["required_ruby_version"]
    errors << "required_rubygems_version mismatch" if spec.required_rubygems_version.to_s != expected["required_rubygems_version"]

    # NOTE: We don't validate files list because RubyGems specifications reset the files
    # array during marshal deserialization (it gets filtered based on disk state).
    # This is the actual behavior we're testing for backwards compatibility.

    # Validate dependencies
    if expected["dependencies"] && !expected["dependencies"].empty?
      expected_deps = expected["dependencies"].map {|d| [d["name"], d["requirement"], d["type"].to_sym] }.sort
      actual_deps = spec.dependencies.map {|d| [d.name, d.requirement.to_s, d.type] }.sort
      errors << "dependencies mismatch: expected #{expected_deps}, got #{actual_deps}" if actual_deps != expected_deps
    end

    if errors.empty?
      record_success("gemspec", test_name, "All attributes validated successfully (#{spec.files.size} files, #{spec.dependencies.size} deps)")
    else
      record_failure("gemspec", test_name, "Attribute validation errors: #{errors.join("; ")}")
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
        record_failure("marshal_index", test_name, "Deserialization failed: #{e.message}")
      end
    end
  end

  def validate_marshal_index_data(data, expected, test_name)
    errors = []

    errors << "not an array" unless data.is_a?(Array)
    errors << "size mismatch: expected #{expected.size}, got #{data.size}" if data.size != expected.size

    # Validate each gem entry
    data.each_with_index do |gem_data, i|
      expected_gem = expected[i]
      next unless expected_gem

      if gem_data.is_a?(Hash)
        errors << "gem #{i} name mismatch" if gem_data[:name] != expected_gem["name"]
        errors << "gem #{i} version mismatch" if gem_data[:number] != expected_gem["number"]
        errors << "gem #{i} platform mismatch" if gem_data[:platform] != expected_gem["platform"]
      else
        errors << "gem #{i} is not a hash: #{gem_data.class}"
      end
    end

    if errors.empty?
      record_success("marshal_index", test_name, "All index data validated successfully")
    else
      record_failure("marshal_index", test_name, "Index validation errors: #{errors.join(", ")}")
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
        record_failure("safe_marshal", test_name, "Deserialization failed: #{e.message}")
      end
    end
  end

  def validate_safe_marshal_object(object, expected, test_name)
    errors = []

    # Check class
    errors << "class mismatch: expected #{expected["class"]}, got #{object.class}" if object.class.name != expected["class"]

    # Check string representations (if they should be stable)
    unless expected["class"] == "Time" # Time objects may have different string representations
      errors << "to_s mismatch" if object.to_s != expected["to_s"]
    end

    # Type-specific validations
    case object
    when Gem::Version
      errors << "version mismatch" if object.version != expected["version"]
    when Gem::Dependency
      errors << "name mismatch" if object.name != expected["name"]
      errors << "requirement mismatch" if object.requirement.to_s != expected["requirement"]
      errors << "type mismatch" if object.type != expected["type"].to_sym
    when Hash
      errors << "size mismatch" if object.size != expected["size"]
    when Array
      errors << "size mismatch" if object.size != expected["size"]
    end

    if errors.empty?
      record_success("safe_marshal", test_name, "Object validated successfully")
    else
      record_failure("safe_marshal", test_name, "Object validation errors: #{errors.join(", ")}")
    end
  end

  def record_success(category, test_name, message)
    @successes << { category: category, test: test_name, message: message }
    puts "  ✓ #{message}"
  end

  def record_failure(category, test_name, message)
    @failures << { category: category, test: test_name, message: message }
    puts "  ✗ #{message}"
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
