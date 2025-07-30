#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"
require "bundler"
require "fileutils"
require "json"
require "tmpdir"
require "time"
require_relative "test_cases"

class TestDataGenerator
  def initialize(direction, output_dir)
    @direction = direction # "forward" or "backward"
    @output_dir = output_dir
    @metadata = {
      generated_at: Time.now.iso8601,
      rubygems_version: Gem::VERSION,
      bundler_version: Bundler::VERSION,
      ruby_version: RUBY_VERSION,
      direction: direction,
    }

    ensure_output_dir
  end

  def generate_all
    puts "Generating #{@direction} compatibility test data..."
    puts "RubyGems version: #{Gem::VERSION}"
    puts "Bundler version: #{Bundler::VERSION}"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Output directory: #{@output_dir}"
    puts

    generate_gemspec_data
    generate_marshal_index_data
    generate_nametuple_index_data
    generate_lockfile_data
    generate_safe_marshal_data

    write_metadata
    puts "Test data generation complete!"
  end

  private

  def ensure_output_dir
    FileUtils.mkdir_p(@output_dir)
    FileUtils.mkdir_p(File.join(@output_dir, "gemspecs"))
    FileUtils.mkdir_p(File.join(@output_dir, "marshal_indexes"))
    FileUtils.mkdir_p(File.join(@output_dir, "nametuple_indexes"))
    FileUtils.mkdir_p(File.join(@output_dir, "lockfiles"))
    FileUtils.mkdir_p(File.join(@output_dir, "safe_marshal"))
  end

  def generate_gemspec_data
    puts "Generating gemspec serialization data..."

    # Create a temporary directory for stub files
    Dir.mktmpdir do |temp_dir|
      create_stub_files(temp_dir)

      # Change to temp dir so gemspecs can find their files
      Dir.chdir(temp_dir) do
        CompatibilityTestCases::GEMSPEC_CASES.each do |test_case|
          puts "  - #{test_case[:name]}: #{test_case[:description]}"

          begin
            spec = test_case[:builder].call

            # Ensure the spec sees the files by calling files method which triggers file discovery
            _ = spec.files

            # Marshal dump
            marshal_data = Marshal.dump(spec)
            write_binary_file("gemspecs/#{test_case[:name]}.marshal", marshal_data)

            # Store spec attributes for validation
            spec_data = {
              name: spec.name,
              version: spec.version.to_s,
              summary: spec.summary,
              description: spec.description,
              authors: spec.authors,
              email: spec.email,
              homepage: spec.homepage,
              license: spec.license,
              licenses: spec.licenses,
              platform: spec.platform.to_s,
              required_ruby_version: spec.required_ruby_version.to_s,
              required_rubygems_version: spec.required_rubygems_version.to_s,
              files: spec.files,
              executables: spec.executables,
              require_paths: spec.require_paths,
              dependencies: spec.dependencies.map do |dep|
                {
                  name: dep.name,
                  requirement: dep.requirement.to_s,
                  type: dep.type,
                }
              end,
              metadata: spec.metadata,
            }

            write_json_file("gemspecs/#{test_case[:name]}.json", spec_data)
          rescue StandardError => e
            puts "    ERROR: #{e.class}: #{e.message}"
            puts "    Backtrace: #{e.backtrace[0..4].join("\n    ")}" if e.backtrace
            next
          end
        end
      end
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

  def generate_marshal_index_data
    puts "Generating marshal index data..."

    CompatibilityTestCases::MARSHAL_INDEX_CASES.each do |test_case|
      puts "  - #{test_case[:name]}: #{test_case[:description]}"

      begin
        data = test_case[:builder].call

        # Marshal dump (simulating dependency API response)
        marshal_data = Marshal.dump(data)
        write_binary_file("marshal_indexes/#{test_case[:name]}.marshal", marshal_data)

        # Store original data for validation
        write_json_file("marshal_indexes/#{test_case[:name]}.json", data)
      rescue StandardError => e
        puts "    ERROR: #{e.message}"
        next
      end
    end
  end

  def generate_nametuple_index_data
    puts "Generating NameTuple index data..."

    # Load SafeMarshal if available
    Gem.load_safe_marshal if Gem.respond_to?(:load_safe_marshal)

    CompatibilityTestCases::NAMETUPLE_INDEX_CASES.each do |test_case|
      puts "  - #{test_case[:name]}: #{test_case[:description]}"

      begin
        spec_tuples = test_case[:builder].call

        # Marshal the raw spec tuple data (as would be in specs.4.8.gz)
        marshal_data = Marshal.dump(spec_tuples)
        write_binary_file("nametuple_indexes/#{test_case[:name]}.marshal", marshal_data)

        # SafeMarshal is only for loading, not dumping - all data is marshaled with regular Marshal
        # The distinction is made during loading for safety

        # Store original data for validation
        serializable_data = spec_tuples.map do |name, version, platform|
          {
            name: name,
            version: version.to_s,
            platform: platform,
          }
        end
        write_json_file("nametuple_indexes/#{test_case[:name]}.json", serializable_data)
      rescue StandardError => e
        puts "    ERROR: #{e.class}: #{e.message}"
        puts "    Backtrace: #{e.backtrace[0..4].join("\n    ")}" if e.backtrace
        next
      end
    end
  end

  def generate_lockfile_data
    puts "Generating lockfile data..."

    Dir.mktmpdir do |temp_dir|
      CompatibilityTestCases::LOCKFILE_CASES.each do |test_case|
        puts "  - #{test_case[:name]}: #{test_case[:description]}"

        begin
          # Create temporary Gemfile
          gemfile_path = File.join(temp_dir, "Gemfile")
          File.write(gemfile_path, test_case[:gemfile_content])

          # Generate lockfile using current Bundler
          lockfile_path = File.join(temp_dir, "Gemfile.lock")

          # Run bundle install to generate lockfile
          Dir.chdir(temp_dir) do
            # Use a fake source to avoid actual network calls
            ENV["BUNDLE_DISABLE_NETWORK"] = "true"
            system("bundle install --local", out: File::NULL, err: File::NULL)
          end

          if File.exist?(lockfile_path)
            lockfile_content = File.read(lockfile_path)
            write_text_file("lockfiles/#{test_case[:name]}.lock", lockfile_content)
            write_text_file("lockfiles/#{test_case[:name]}.gemfile", test_case[:gemfile_content])
          else
            puts "    WARNING: Failed to generate lockfile for #{test_case[:name]}"
          end
        rescue StandardError => e
          puts "    ERROR: #{e.message}"
          next
        ensure
          # Clean up
          ENV.delete("BUNDLE_DISABLE_NETWORK")
          FileUtils.rm_f([gemfile_path, lockfile_path])
        end
      end
    end
  end

  def generate_safe_marshal_data
    puts "Generating safe marshal data..."

    CompatibilityTestCases::SAFE_MARSHAL_CASES.each do |test_case|
      puts "  - #{test_case[:name]}: #{test_case[:description]}"

      begin
        object = test_case[:builder].call

        # Marshal dump
        marshal_data = Marshal.dump(object)
        write_binary_file("safe_marshal/#{test_case[:name]}.marshal", marshal_data)

        # Store object info for validation
        object_data = {
          class: object.class.name,
          inspect: object.inspect,
          to_s: object.to_s,
        }

        # Add type-specific data
        case object
        when Hash
          object_data[:keys] = object.keys
          object_data[:size] = object.size
        when Array
          object_data[:size] = object.size
        when Gem::Version
          object_data[:version] = object.version
        when Gem::Requirement
          object_data[:requirements] = object.requirements.map(&:to_s)
        when Gem::Dependency
          object_data[:name] = object.name
          object_data[:requirement] = object.requirement.to_s
          object_data[:type] = object.type
        when Time
          object_data[:iso8601] = object.iso8601
          object_data[:zone] = object.zone
        end

        write_json_file("safe_marshal/#{test_case[:name]}.json", object_data)
      rescue StandardError => e
        puts "    ERROR: #{e.message}"
        next
      end
    end
  end

  def write_binary_file(path, data)
    full_path = File.join(@output_dir, path)
    File.open(full_path, "wb") {|f| f.write(data) }
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
    metadata_file = File.join(@output_dir, "metadata.json")
    File.write(metadata_file, JSON.pretty_generate(@metadata))
  end
end

# Main execution
if ARGV.length != 2
  puts "Usage: #{$0} <direction> <output_dir>"
  puts "  direction: 'forward' or 'backward'"
  puts "  output_dir: directory to write test data"
  exit 1
end

direction, output_dir = ARGV
generator = TestDataGenerator.new(direction, output_dir)
generator.generate_all
