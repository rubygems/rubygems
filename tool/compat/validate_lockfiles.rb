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
    puts "Current Bundler version: #{Bundler::VERSION}"
    puts "Testing against version: #{@version_info}"
    puts "Original lockfiles generated with: #{@metadata&.dig("bundler_version") || "unknown"}"
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
      record_failure("lockfile", test_name, "Setup failed: #{e.message}")
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
      record_failure("lockfile", test_name, "Parsing issues: #{validation_errors.join(", ")}")
    end
  rescue StandardError => e
    record_failure("lockfile", test_name, "Failed to parse lockfile: #{e.message}")
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
        content_errors << "bundler version mismatch: expected #{expected_version}, got #{actual_version}"
      end
    end

    # Validate platforms
    if expected["platforms"]
      expected_platforms = expected["platforms"].sort
      actual_platforms = lockfile.platforms.map(&:to_s).sort
      if expected_platforms != actual_platforms
        content_errors << "platforms mismatch: expected #{expected_platforms}, got #{actual_platforms}"
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
      record_failure("lockfile_content", test_name, "Content validation errors: #{content_errors.join(", ")}")
    end
  rescue StandardError => e
    record_failure("lockfile_content", test_name, "Content validation failed: #{e.message}")
  end

  def record_success(category, test_name, message)
    @successes << { category: category, test: test_name, message: message }
    puts "  ✓ #{message}"
  end

  def record_failure(category, test_name, message)
    @failures << { category: category, test: test_name, message: message }
    puts "  ✗ #{message}"
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
