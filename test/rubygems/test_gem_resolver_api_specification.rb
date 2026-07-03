# frozen_string_literal: true

require_relative "helper"

class TestGemResolverAPISpecification < Gem::TestCase
  def test_initialize
    set = Gem::Resolver::APISet.new
    data = {
      name: "rails",
      number: "3.0.3",
      suffix: Gem::Platform.local.to_s,
      dependencies: [
        ["bundler",  "~> 1.0"],
        ["railties", "= 3.0.3"],
      ],
    }

    spec = Gem::Resolver::APISpecification.new set, data

    assert_equal "rails",                   spec.name
    assert_equal Gem::Version.new("3.0.3"), spec.version
    assert_equal Gem::Platform.local,       spec.platform
    refute spec.content_addressable?
    assert_nil spec.content_address

    expected = [
      Gem::Dependency.new("bundler",  "~> 1.0"),
      Gem::Dependency.new("railties", "= 3.0.3"),
    ]

    assert_equal expected, spec.dependencies
    assert_nil spec.created_at
  end

  def test_initialize_content_addressable
    set = Gem::Resolver::APISet.new
    data = {
      name: "darwin-demo",
      number: "1.0.0",
      suffix: "bd0ec167",
      dependencies: [],
      requirements: { ruby: ["~> 3.4.0"], platform: ["= arm64-darwin"] },
    }

    spec = Gem::Resolver::APISpecification.new set, data

    assert spec.content_addressable?
    assert_equal "bd0ec167", spec.content_address
    assert_equal Gem::Platform.new("arm64-darwin"), spec.platform
    assert_equal "darwin-demo-1.0.0-bd0ec167", spec.spec.full_name
    assert_equal "bd0ec167", spec.spec.content_address
  end

  def test_initialize_created_at
    set = Gem::Resolver::APISet.new
    data = {
      name: "rails",
      number: "3.0.3",
      suffix: "ruby",
      dependencies: [],
      requirements: { created_at: ["2026-06-05T10:30:45Z"] },
    }

    spec = Gem::Resolver::APISpecification.new set, data

    assert_equal Time.utc(2026, 6, 5, 10, 30, 45), spec.created_at
  end

  def test_initialize_created_at_invalid
    set = Gem::Resolver::APISet.new
    data = {
      name: "rails",
      number: "3.0.3",
      suffix: "ruby",
      dependencies: [],
      requirements: { created_at: ["not a timestamp"] },
    }

    spec = Gem::Resolver::APISpecification.new set, data

    assert_nil spec.created_at
  end

  def test_initialize_created_at_non_iso8601
    set = Gem::Resolver::APISet.new
    data = {
      name: "rails",
      number: "3.0.3",
      suffix: "ruby",
      dependencies: [],
      requirements: { created_at: ["2026"] },
    }

    spec = Gem::Resolver::APISpecification.new set, data

    assert_nil spec.created_at
  end

  def test_fetch_development_dependencies
    specs = spec_fetcher do |fetcher|
      fetcher.spec "rails", "3.0.3" do |s|
        s.add_runtime_dependency "bundler",  "~> 1.0"
        s.add_runtime_dependency "railties", "= 3.0.3"
        s.add_development_dependency "a",    "= 1"
      end
    end

    rails = specs["rails-3.0.3"]

    repo = @gem_repo + "info"

    set = Gem::Resolver::APISet.new repo

    data = {
      name: "rails",
      number: "3.0.3",
      suffix: "ruby",
      dependencies: [
        ["bundler",  "~> 1.0"],
        ["railties", "= 3.0.3"],
      ],
    }

    util_setup_spec_fetcher rails

    spec = Gem::Resolver::APISpecification.new set, data

    spec.fetch_development_dependencies

    expected = [
      Gem::Dependency.new("bundler",  "~> 1.0"),
      Gem::Dependency.new("railties", "= 3.0.3"),
      Gem::Dependency.new("a",        "= 1", :development),
    ]

    assert_equal expected, spec.dependencies
  end

  def test_installable_platform_eh
    set = Gem::Resolver::APISet.new
    data = {
      name: "a",
      number: "1",
      suffix: "ruby",
      dependencies: [],
    }

    a_spec = Gem::Resolver::APISpecification.new set, data

    assert a_spec.installable_platform?

    data = {
      name: "b",
      number: "1",
      suffix: "cpu-other_platform-1",
      dependencies: [],
    }

    b_spec = Gem::Resolver::APISpecification.new set, data

    refute b_spec.installable_platform?

    data = {
      name: "c",
      number: "1",
      suffix: Gem::Platform.local.to_s,
      dependencies: [],
    }

    c_spec = Gem::Resolver::APISpecification.new set, data

    assert c_spec.installable_platform?
  end

  def test_source
    set = Gem::Resolver::APISet.new
    data = {
      name: "a",
      number: "1",
      suffix: "ruby",
      dependencies: [],
    }

    api_spec = Gem::Resolver::APISpecification.new set, data

    assert_equal set.source, api_spec.source
  end

  def test_spec
    spec_fetcher do |fetcher|
      fetcher.spec "a", 1
    end

    dep_uri = Gem::URI(@gem_repo) + "info"
    set = Gem::Resolver::APISet.new dep_uri
    data = {
      name: "a",
      number: "1",
      suffix: "ruby",
      dependencies: [],
    }

    api_spec = Gem::Resolver::APISpecification.new set, data

    spec = api_spec.spec

    assert_kind_of Gem::Specification, spec
    assert_equal "a-1", spec.full_name
  end

  def test_spec_jruby_platform
    spec_fetcher do |fetcher|
      fetcher.gem "j", 1 do |spec|
        spec.platform = "jruby"
      end
    end

    dep_uri = Gem::URI(@gem_repo) + "info"
    set = Gem::Resolver::APISet.new dep_uri
    data = {
      name: "j",
      number: "1",
      suffix: "jruby",
      dependencies: [],
    }

    api_spec = Gem::Resolver::APISpecification.new set, data

    spec = api_spec.spec

    assert_kind_of Gem::Specification, spec
    assert_equal "j-1-java", spec.full_name
  end
end
