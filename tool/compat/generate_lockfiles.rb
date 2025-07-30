#!/usr/bin/env ruby
# frozen_String_literal: true

require "bundler"
require "fileutils"
require "json"
require "tmpdir"
require "time"
require_relative "test_cases"

class LockfileGenerator
  def initialize(bundler_version, output_dir)
    @bundler_version = bundler_version
    @output_dir = output_dir
    @metadata = {
      generated_at: Time.now.iso8601,
      bundler_version: bundler_version,
      actual_bundler_version: Bundler::VERSION,
      ruby_version: RUBY_VERSION,
    }

    ensure_output_dir
  end

  def generate_all
    puts "Generating lockfiles with Bundler #{@bundler_version}..."
    puts "Actual Bundler version: #{Bundler::VERSION}"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Output directory: #{@output_dir}"
    puts

    generate_lockfiles
    write_metadata
    puts "Lockfile generation complete!"
  end

  private

  def ensure_output_dir
    FileUtils.mkdir_p(@output_dir)
    FileUtils.mkdir_p(File.join(@output_dir, "lockfiles"))
  end

  def generate_lockfiles
    Dir.mktmpdir do |temp_dir|
      CompatibilityTestCases::LOCKFILE_CASES.each do |test_case|
        puts "  - #{test_case[:name]}: #{test_case[:description]}"

        begin
          project_dir = File.join(temp_dir, test_case[:name])
          FileUtils.mkdir_p(project_dir)

          # Create Gemfile
          gemfile_path = File.join(project_dir, "Gemfile")
          File.write(gemfile_path, test_case[:gemfile_content])

          # Create a simple Ruby file to make it a valid project
          lib_dir = File.join(project_dir, "lib")
          FileUtils.mkdir_p(lib_dir)
          File.write(File.join(lib_dir, "app.rb"), "# Simple Ruby app")

          # Generate lockfile
          lockfile_path = File.join(project_dir, "Gemfile.lock")

          Dir.chdir(project_dir) do
            # Try to resolve and create lockfile without actually installing gems
            success = system("bundle lock", out: File::NULL, err: File::NULL)

            if success && File.exist?(lockfile_path)
              lockfile_content = File.read(lockfile_path)

              # Copy files to output directory
              # Use actual Bundler version for "current"
              version_label = @bundler_version == "current" ? Bundler::VERSION : @bundler_version
              output_prefix = "#{version_label}_#{test_case[:name]}"
              write_text_file("lockfiles/#{output_prefix}.lock", lockfile_content)
              write_text_file("lockfiles/#{output_prefix}.gemfile", test_case[:gemfile_content])

              # Extract lockfile metadata
              lockfile_data = parse_lockfile_metadata(lockfile_content)
              write_json_file("lockfiles/#{output_prefix}.json", lockfile_data)

            else
              puts "    WARNING: Failed to generate lockfile for #{test_case[:name]}"
            end
          end
        rescue StandardError => e
          puts "    ERROR: #{e.class}: #{e.message}"
          puts "    Backtrace: #{e.backtrace[0..4].join("\n    ")}" if e.backtrace
          next
        end
      end
    end
  end

  def parse_lockfile_metadata(lockfile_content)
    metadata = {
      bundled_with: nil,
      gems: [],
      platforms: [],
      dependencies: [],
    }

    current_section = nil

    lockfile_content.each_line do |line|
      line = line.chomp

      case line
      when /^GEM$/
        current_section = :gem
      when /^PLATFORMS$/
        current_section = :platforms
      when /^DEPENDENCIES$/
        current_section = :dependencies
      when /^BUNDLED WITH$/
        current_section = :bundled_with
      when /^$/
        current_section = nil
      else
        case current_section
        when :gem
          if line =~ /^\s+(\w+)\s+\(([^)]+)\)$/
            metadata[:gems] << { name: $1, version: $2 }
          end
        when :platforms
          if line =~ /^\s+(.+)$/
            metadata[:platforms] << $1.strip
          end
        when :dependencies
          if line =~ /^\s+(.+)$/
            metadata[:dependencies] << $1.strip
          end
        when :bundled_with
          if line =~ /^\s+(.+)$/
            metadata[:bundled_with] = $1.strip
          end
        end
      end
    end

    metadata
  end

  def write_text_file(path, content)
    full_path = File.join(@output_dir, path)
    File.write(full_path, content)
  end

  def write_json_file(path, data)
    full_path = File.join(@output_dir, path)
    File.write(full_path, JSON.pretty_generate(data))
  end

  def write_metadata
    metadata_file = File.join(@output_dir, "lockfile_metadata.json")
    File.write(metadata_file, JSON.pretty_generate(@metadata))
  end
end

# Main execution
if ARGV.length != 2
  puts "Usage: #{$0} <bundler_version> <output_dir>"
  puts "  bundler_version: version of Bundler used to generate lockfiles"
  puts "  output_dir: directory to write lockfile data"
  exit 1
end

bundler_version, output_dir = ARGV
generator = LockfileGenerator.new(bundler_version, output_dir)
generator.generate_all
