# frozen_string_literal: true

# Test cases for backwards compatibility testing
module CompatibilityTestCases
  # Gemspec serialization test cases
  GEMSPEC_CASES = [
    {
      name: "minimal_gemspec",
      description: "Minimal gemspec with basic attributes",
      builder: -> {
        Gem::Specification.new do |s|
          s.name = "test-gem"
          s.version = "1.0.0"
          s.summary = "A test gem"
          s.files = ["lib/test.rb"]
        end
      },
    },
    {
      name: "full_gemspec",
      description: "Full gemspec with all common attributes",
      builder: -> {
        Gem::Specification.new do |s|
          s.name = "complex-gem"
          s.version = "2.1.3"
          s.summary = "A complex test gem"
          s.description = "This is a more complex gem for testing serialization"
          s.authors = ["Test Author", "Another Author"]
          s.email = ["test@example.com", "another@example.com"]
          s.homepage = "https://example.com"
          s.license = "MIT"
          s.licenses = ["MIT", "Apache-2.0"]
          s.platform = Gem::Platform::RUBY
          s.required_ruby_version = ">= 2.7.0"
          s.required_rubygems_version = ">= 3.0.0"
          s.files = ["lib/complex.rb", "README.md", "LICENSE"]
          s.executables = ["complex-tool"]
          s.require_paths = ["lib"]
          s.metadata = {
            "bug_tracker_uri" => "https://github.com/example/complex-gem/issues",
            "changelog_uri" => "https://github.com/example/complex-gem/blob/main/CHANGELOG.md",
            "source_code_uri" => "https://github.com/example/complex-gem",
          }
        end
      },
    },
    {
      name: "gemspec_with_dependencies",
      description: "Gemspec with runtime and development dependencies",
      builder: -> {
        Gem::Specification.new do |s|
          s.name = "dep-gem"
          s.version = "1.5.0"
          s.summary = "Gem with dependencies"
          s.files = ["lib/dep.rb"]

          s.add_dependency "json", "~> 2.0"
          s.add_dependency "rake", ">= 12.0"
          s.add_development_dependency "rspec", "~> 3.0"
          s.add_development_dependency "rubocop", ">= 1.0"
        end
      },
    },
    {
      name: "gemspec_with_extensions",
      description: "Gemspec with native extensions",
      builder: -> {
        Gem::Specification.new do |s|
          s.name = "native-gem"
          s.version = "0.9.0"
          s.summary = "Gem with native extensions"
          s.files = ["lib/native.rb", "ext/native/extconf.rb", "ext/native/native.c"]
          s.extensions = ["ext/native/extconf.rb"]
          s.require_paths = ["lib"]
        end
      },
    },
  ].freeze

  # Marshal index test cases (simulated dependency API responses)
  MARSHAL_INDEX_CASES = [
    {
      name: "simple_dependency_response",
      description: "Simple dependency API response",
      builder: -> {
        [
          {
            name: "test-gem",
            number: "1.0.0",
            platform: "ruby",
            dependencies: [
              ["json", "~> 2.0"],
              ["rake", ">= 12.0"],
            ],
          },
        ]
      },
    },
    {
      name: "complex_dependency_response",
      description: "Complex dependency API response with multiple gems",
      builder: -> {
        [
          {
            name: "web-framework",
            number: "3.2.1",
            platform: "ruby",
            dependencies: [
              ["activesupport", "= 3.2.1"],
              ["builder", "~> 3.0.0"],
              ["rack", "~> 1.4.0"],
            ],
          },
          {
            name: "activesupport",
            number: "3.2.1",
            platform: "ruby",
            dependencies: [
              ["i18n", "~> 0.6"],
              ["multi_json", "~> 1.0"],
            ],
          },
        ]
      },
    },
  ].freeze

  # Lockfile test cases
  LOCKFILE_CASES = [
    {
      name: "simple_gemfile",
      description: "Simple Gemfile for lockfile generation",
      gemfile_content: <<~GEMFILE,
        source "https://rubygems.org"

        gem "json", "~> 2.0"
        gem "rake", ">= 12.0"
      GEMFILE
    },
    {
      name: "complex_gemfile",
      description: "Complex Gemfile with groups and platforms",
      gemfile_content: <<~GEMFILE,
        source "https://rubygems.org"

        gem "rails", "~> 7.0"
        gem "pg", "~> 1.1"
        gem "redis", "~> 4.0"

        group :development, :test do
          gem "rspec-rails", "~> 5.0"
          gem "factory_bot_rails", "~> 6.0"
        end

        group :development do
          gem "rubocop", require: false
          gem "brakeman", require: false
        end

        platforms :ruby do
          gem "sqlite3", "~> 1.4"
        end

        platforms :jruby do
          gem "activerecord-jdbcsqlite3-adapter"
        end
      GEMFILE
    },
    {
      name: "git_source_gemfile",
      description: "Gemfile with git sources",
      gemfile_content: <<~GEMFILE,
        source "https://rubygems.org"

        gem "rails", "~> 7.0"
        gem "custom-gem", git: "https://github.com/example/custom-gem.git", branch: "main"
        gem "forked-gem", git: "https://github.com/myuser/forked-gem.git", tag: "v1.2.3"
      GEMFILE
    },
  ].freeze

  # NameTuple spec index test cases (real-world gem index loading)
  NAMETUPLE_INDEX_CASES = [
    {
      name: "gem_spec_index",
      description: "Real gem specification index as used by Gem::Source#load_specs",
      builder: -> { 
        # Create realistic NameTuple data as would be found in specs.4.8.gz
        specs = [
          ["rake", Gem::Version.new("13.0.6"), "ruby"],
          ["json", Gem::Version.new("2.6.3"), "ruby"],
          ["bundler", Gem::Version.new("2.4.19"), "ruby"],
          ["rspec", Gem::Version.new("3.12.0"), "ruby"],
          ["activerecord", Gem::Version.new("7.0.4"), "ruby"],
        ]
        
        # Convert to NameTuple format
        specs.map { |name, version, platform| [name, version, platform] }
      },
    },
    {
      name: "gem_spec_index_with_platforms",
      description: "Gem specification index with multiple platforms",
      builder: -> { 
        [
          ["nokogiri", Gem::Version.new("1.15.4"), "ruby"],
          ["nokogiri", Gem::Version.new("1.15.4"), "x86_64-linux"],
          ["nokogiri", Gem::Version.new("1.15.4"), "arm64-darwin"],
          ["ffi", Gem::Version.new("1.15.5"), "ruby"],
          ["ffi", Gem::Version.new("1.15.5"), "x86_64-linux"],
        ]
      },
    },
  ].freeze

  # Safe marshal test cases (specific data types that should be preserved)
  SAFE_MARSHAL_CASES = [
    {
      name: "gem_version",
      description: "Gem::Version objects",
      builder: -> { Gem::Version.new("1.2.3.pre.alpha.1") },
    },
    {
      name: "gem_requirement",
      description: "Gem::Requirement objects",
      builder: -> { Gem::Requirement.new([">= 1.0", "< 2.0"]) },
    },
    {
      name: "gem_dependency",
      description: "Gem::Dependency objects",
      builder: -> {
        Gem::Dependency.new("test-gem", Gem::Requirement.new("~> 1.0"), :runtime)
      },
    },
    {
      name: "gem_platform",
      description: "Gem::Platform objects",
      builder: -> { Gem::Platform.new("x86_64-linux") },
    },
    {
      name: "time_objects",
      description: "Time objects with various timezones",
      builder: -> { Time.new(2023, 12, 25, 10, 30, 45, "-05:00") },
    },
    {
      name: "complex_hash",
      description: "Complex hash with nested structures",
      builder: -> {
        {
          "metadata" => {
            "version" => "1.0.0",
            "dependencies" => ["json", "rake"],
            "nested" => {
              "deep" => true,
              "count" => 42,
            },
          },
          "platform" => "ruby",
          "created_at" => Time.now,
        }
      },
    },
  ].freeze

  def self.all_cases
    {
      gemspecs: GEMSPEC_CASES,
      marshal_indexes: MARSHAL_INDEX_CASES,
      nametuple_indexes: NAMETUPLE_INDEX_CASES,
      lockfiles: LOCKFILE_CASES,
      safe_marshal: SAFE_MARSHAL_CASES,
    }
  end
end
