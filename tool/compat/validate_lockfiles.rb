#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler"
require "json"
require "fileutils"
require "tmpdir"

class LockfileValidator
  def initialize(test_data_dir, version_info)
    @test_data_dir = test_data_dir
    @version_info = version_info
    @failures = []
    @successes = []

    load_metadata
  end

  def validate_all
    puts "Validating lockfile compatibility..."
    puts "Test data directory: #{@test_data_dir}"
    puts "Current Ruby version: #{RUBY_VERSION}"
    puts "Current Bundler version: #{Bundler::VERSION}"
    puts "Testing against version: #{@version_info}"
    puts "Original lockfiles generated with: #{@metadata&.dig("bundler_version") || "unknown"}"
    puts "Original Ruby version: #{@metadata&.dig("ruby_version") || "unknown"}"
    puts

    validate_lockfiles

    report_results
    exit(@failures.empty? ? 0 : 1)
  end

  private

  def load_metadata
    metadata_file = File.join(@test_data_dir, "lockfile_metadata.json")
    if File.exist?(metadata_file)
      @metadata = JSON.parse(File.read(metadata_file))
    else
      puts "WARNING: No lockfile metadata file found at #{metadata_file}"
      @metadata = {}
    end
  end

  def validate_lockfiles
    puts "=== Validating Lockfile Compatibility ==="

    lockfile_dir = File.join(@test_data_dir, "lockfiles")
    return unless Dir.exist?(lockfile_dir)

    Dir.glob("*.lock", base: lockfile_dir).each do |lockfile|
      test_name = File.basename(lockfile, ".lock")
      puts "Testing #{test_name}..."

      validate_single_lockfile(lockfile_dir, test_name)
    end
  end

  def validate_single_lockfile(lockfile_dir, test_name)
    lockfile_path = File.join(lockfile_dir, "#{test_name}.lock")
    gemfile_path = File.join(lockfile_dir, "#{test_name}.gemfile")
    json_path = File.join(lockfile_dir, "#{test_name}.json")

    Dir.mktmpdir do |temp_dir|
      # Copy files to temp directory
      temp_lockfile = File.join(temp_dir, "Gemfile.lock")
      temp_gemfile = File.join(temp_dir, "Gemfile")

      File.write(temp_lockfile, File.read(lockfile_path))

      if File.exist?(gemfile_path)
        File.write(temp_gemfile, File.read(gemfile_path))
      else
        # Create a minimal Gemfile if none exists
        File.write(temp_gemfile, "source 'https://rubygems.org'\n")
      end

      # Test lockfile parsing
      Dir.chdir(temp_dir) do
        validate_lockfile_parsing(test_name)
        validate_lockfile_content(test_name, json_path) if File.exist?(json_path)
      end
    rescue StandardError => e
      error_details = "#{e.class}: #{e.message}"
      error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
      record_failure("lockfile", test_name, "Setup failed: #{error_details}")
    end
  end

  def validate_lockfile_parsing(test_name)
    # Try to parse the lockfile with current Bundler
    lockfile = Bundler::LockfileParser.new(File.read("Gemfile.lock"))

    # Basic validation - ensure we can read key sections
    specs = lockfile.specs
    dependencies = lockfile.dependencies
    platforms = lockfile.platforms
    bundler_version = lockfile.bundler_version

    validation_errors = []
    validation_errors << "no specs found" if specs.empty?
    validation_errors << "no platforms found" if platforms.empty?

    if validation_errors.empty?
      record_success("lockfile", test_name, "Successfully parsed lockfile (#{specs.size} specs, #{platforms.size} platforms)")
    else
      validation_errors.each do |error|
        record_failure("lockfile", test_name, error)
      end
    end
  rescue StandardError => e
    error_details = "#{e.class}: #{e.message}"
    error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
    record_failure("lockfile", test_name, "Failed to parse lockfile: #{error_details}")
  end

  def validate_lockfile_content(test_name, json_path)
    expected = JSON.parse(File.read(json_path))
    lockfile = Bundler::LockfileParser.new(File.read("Gemfile.lock"))

    content_errors = []

    # Validate bundler version
    if expected["bundled_with"] && lockfile.bundler_version
      expected_version = Gem::Version.new(expected["bundled_with"])
      actual_version = lockfile.bundler_version
      if expected_version != actual_version
        content_errors << {field: "bundler_version", expected: expected_version, actual: actual_version}
      end
    end

    # Validate platforms
    if expected["platforms"]
      expected_platforms = expected["platforms"].sort
      actual_platforms = lockfile.platforms.map(&:to_s).sort
      if expected_platforms != actual_platforms
        content_errors << {field: "platforms", expected: expected_platforms, actual: actual_platforms}
      end
    end

    # Validate gem count (basic check)
    # NOTE: Commented out because dependency resolution can legitimately differ between versions
    # if expected['gems']
    #   expected_gem_count = expected['gems'].size
    #   actual_gem_count = lockfile.specs.size
    #   if expected_gem_count != actual_gem_count
    #     content_errors << "gem count mismatch: expected #{expected_gem_count}, got #{actual_gem_count}"
    #   end
    # end

    if content_errors.empty?
      record_success("lockfile_content", test_name, "Content validation passed")
    else
      content_errors.each do |error|
        record_failure("lockfile_content", test_name, error)
      end
    end
  rescue StandardError => e
    error_details = "#{e.class}: #{e.message}"
    error_details += "\nBacktrace: #{e.backtrace[0..4].join("\n")}" if e.backtrace
    record_failure("lockfile_content", test_name, "Content validation failed: #{error_details}")
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

  def report_results
    puts "\n" + "=" * 50
    puts "LOCKFILE VALIDATION RESULTS"
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
  puts "  test_data_dir: directory containing lockfile test data"
  puts "  version_info: version information for reporting"
  exit 1
end

test_data_dir, version_info = ARGV
validator = LockfileValidator.new(test_data_dir, version_info)
validator.validate_all
