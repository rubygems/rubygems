# frozen_string_literal: true

require_relative "helper"
require "rubygems/request_set"

class TestGemRequestSet < Gem::TestCase
  def setup
    super

    Gem::RemoteFetcher.fetcher = @fetcher = Gem::FakeFetcher.new
  end

  def test_gem
    util_spec "a", "2"

    rs = Gem::RequestSet.new
    rs.gem "a", "= 2"

    assert_equal [Gem::Dependency.new("a", "=2")], rs.dependencies
  end

  def test_gem_duplicate
    rs = Gem::RequestSet.new

    rs.gem "a", "1"
    rs.gem "a", "2"

    assert_equal [dep("a", "= 1", "= 2")], rs.dependencies
  end

  def test_import
    rs = Gem::RequestSet.new
    rs.gem "a"

    rs.import [dep("b")]

    assert_equal [dep("a"), dep("b")], rs.dependencies
  end

  def test_resolve
    a = util_spec "a", "2", "b" => ">= 2"
    b = util_spec "b", "2"

    rs = Gem::RequestSet.new
    rs.gem "a"

    orig_errors = rs.errors

    res = rs.resolve StaticSet.new([a, b])
    assert_equal 2, res.size

    names = res.map(&:full_name).sort

    assert_equal ["a-2", "b-2"], names

    refute_same orig_errors, rs.errors
  end

  def test_bug_bug_990
    a = util_spec "a", "1.b",  "b" => "~> 1.a"
    b = util_spec "b", "1.b",  "c" => ">= 1"
    c = util_spec "c", "1.1.b"

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.prerelease = true

    res = rs.resolve StaticSet.new([a, b, c])
    assert_equal 3, res.size

    names = res.map(&:full_name).sort

    assert_equal %w[a-1.b b-1.b c-1.1.b], names
  end

  def test_resolve_development
    a = util_spec "a", 1
    spec = Gem::Resolver::SpecSpecification.new nil, a

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.development = true

    res = rs.resolve StaticSet.new [spec]
    assert_equal 1, res.size

    assert rs.resolver.development
    refute rs.resolver.development_shallow
  end

  def test_resolve_development_shallow
    a = util_spec "a", 1 do |s|
      s.add_development_dependency "b"
    end

    b = util_spec "b", 1 do |s|
      s.add_development_dependency "c"
    end

    c = util_spec "c", 1

    a_spec = Gem::Resolver::SpecSpecification.new nil, a
    b_spec = Gem::Resolver::SpecSpecification.new nil, b
    c_spec = Gem::Resolver::SpecSpecification.new nil, c

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.development = true
    rs.development_shallow = true

    res = rs.resolve StaticSet.new [a_spec, b_spec, c_spec]
    assert_equal 2, res.size

    assert rs.resolver.development
    assert rs.resolver.development_shallow
  end

  def test_resolve_ignore_dependencies
    a = util_spec "a", "2", "b" => ">= 2"
    b = util_spec "b", "2"

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.ignore_dependencies = true

    res = rs.resolve StaticSet.new([a, b])
    assert_equal 1, res.size

    names = res.map(&:full_name).sort

    assert_equal %w[a-2], names
  end

  def test_resolve_incompatible
    a1 = util_spec "a", 1
    a2 = util_spec "a", 2

    rs = Gem::RequestSet.new
    rs.gem "a", "= 1"
    rs.gem "a", "= 2"

    set = StaticSet.new [a1, a2]

    assert_raise Gem::UnsatisfiableDependencyError do
      rs.resolve set
    end
  end

  def test_sorted_requests
    a = util_spec "a", "2", "b" => ">= 2"
    b = util_spec "b", "2", "c" => ">= 2"
    c = util_spec "c", "2"

    rs = Gem::RequestSet.new
    rs.gem "a"

    rs.resolve StaticSet.new([a, b, c])

    names = rs.sorted_requests.map(&:full_name)
    assert_equal %w[c-2 b-2 a-2], names
  end

  def test_install
    done_installing_ran = false

    Gem.done_installing do
      done_installing_ran = true
    end

    spec_fetcher do |fetcher|
      fetcher.download "a", "1", "b" => "= 1"
      fetcher.download "b", "1"
    end

    rs = Gem::RequestSet.new
    rs.gem "a"

    rs.resolve

    reqs       = []
    installers = []

    installed = rs.install({}) do |req, installer|
      reqs       << req
      installers << installer
    end

    assert_equal %w[b-1 a-1], reqs.map(&:full_name)
    assert_equal %w[b-1 a-1],
                 installers.map {|installer| installer.spec.full_name }

    assert_path_exist File.join @gemhome, "specifications", "a-1.gemspec"
    assert_path_exist File.join @gemhome, "specifications", "b-1.gemspec"

    assert_equal %w[b-1 a-1], installed.map(&:full_name)

    assert done_installing_ran
  end

  def test_install_into
    spec_fetcher do |fetcher|
      fetcher.gem "a", "1", "b" => "= 1"
      fetcher.gem "b", "1"
    end

    rs = Gem::RequestSet.new
    rs.gem "a"

    rs.resolve

    installed = rs.install_into @tempdir do
      assert_equal @tempdir, ENV["GEM_HOME"]
    end

    assert_path_exist File.join @tempdir, "specifications", "a-1.gemspec"
    assert_path_exist File.join @tempdir, "specifications", "b-1.gemspec"

    assert_equal %w[b-1 a-1], installed.map(&:full_name)
  end

  def test_install_into_development_shallow
    spec_fetcher do |fetcher|
      fetcher.gem "a", "1" do |s|
        s.add_development_dependency "b", "= 1"
      end

      fetcher.gem "b", "1" do |s|
        s.add_development_dependency "c", "= 1"
      end

      fetcher.spec "c", "1"
    end

    rs = Gem::RequestSet.new
    rs.development         = true
    rs.development_shallow = true
    rs.gem "a"

    rs.resolve

    options = {
      development: true,
      development_shallow: true,
    }

    installed = rs.install_into @tempdir, true, options do
      assert_equal @tempdir, ENV["GEM_HOME"]
    end

    assert_equal %w[a-1 b-1], installed.map(&:full_name).sort
  end

  def test_sorted_requests_development_shallow
    a = util_spec "a", 1 do |s|
      s.add_development_dependency "b"
    end

    b = util_spec "b", 1 do |s|
      s.add_development_dependency "c"
    end

    c = util_spec "c", 1

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.development = true
    rs.development_shallow = true

    a_spec = Gem::Resolver::SpecSpecification.new nil, a
    b_spec = Gem::Resolver::SpecSpecification.new nil, b
    c_spec = Gem::Resolver::SpecSpecification.new nil, c

    rs.resolve StaticSet.new [a_spec, b_spec, c_spec]

    assert_equal %w[b-1 a-1], rs.sorted_requests.map(&:full_name)
  end

  def test_tsort_each_child_development
    a = util_spec "a", 1 do |s|
      s.add_development_dependency "b"
    end

    b = util_spec "b", 1 do |s|
      s.add_development_dependency "c"
    end

    c = util_spec "c", 1

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.development = true
    rs.development_shallow = true

    a_spec = Gem::Resolver::SpecSpecification.new nil, a
    b_spec = Gem::Resolver::SpecSpecification.new nil, b
    c_spec = Gem::Resolver::SpecSpecification.new nil, c

    rs.resolve StaticSet.new [a_spec, b_spec, c_spec]

    a_req = Gem::Resolver::ActivationRequest.new a_spec, nil

    deps = rs.enum_for(:tsort_each_child, a_req).to_a

    assert_equal %w[b], deps.map(&:name)
  end

  def test_tsort_each_child_development_shallow
    a = util_spec "a", 1 do |s|
      s.add_development_dependency "b"
    end

    b = util_spec "b", 1 do |s|
      s.add_development_dependency "c"
    end

    c = util_spec "c", 1

    rs = Gem::RequestSet.new
    rs.gem "a"
    rs.development = true
    rs.development_shallow = true

    a_spec = Gem::Resolver::SpecSpecification.new nil, a
    b_spec = Gem::Resolver::SpecSpecification.new nil, b
    c_spec = Gem::Resolver::SpecSpecification.new nil, c

    rs.resolve StaticSet.new [a_spec, b_spec, c_spec]

    b_req = Gem::Resolver::ActivationRequest.new b_spec, nil

    deps = rs.enum_for(:tsort_each_child, b_req).to_a

    assert_empty deps
  end
end
