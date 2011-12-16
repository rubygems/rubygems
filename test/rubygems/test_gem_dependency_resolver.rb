require 'rubygems/test_case'
require 'rubygems/dependency_resolver'

class TestGemDependencyResolver < Gem::TestCase

  class StaticSet
    def initialize(specs)
      @specs = specs.sort_by { |s| s.full_name }
    end

    def find_spec(dep)
      @specs.reverse_each do |s|
        return s if dep.matches_spec? s
      end
    end

    def find_all(dep)
      @specs.find_all { |s| dep.matches_spec? s }
    end
  end

  def make_dep(name, *req)
    Gem::Dependency.new(name, *req)
  end

  def set(*specs)
    StaticSet.new(specs)
  end

  def assert_set(expected, actual)
    e = expected.sort_by { |s| s.full_name }
    a = actual.map { |a| a.spec }.sort_by { |s| s.full_name }

    assert_equal e, a
  end

  def test_no_overlap_specificly
    a = util_spec "a", '1'
    b = util_spec "b", "1"

    ad = make_dep "a", "= 1"
    bd = make_dep "b", "= 1"

    deps = [ad, bd]

    s = set(a, b)

    res = Gem::DependencyResolver.new(s, deps)

    assert_set [a, b], res.resolve!
  end

  def test_pulls_in_dependencies
    a = util_spec "a", '1'
    b = util_spec "b", "1", "c" => "= 1"
    c = util_spec "c", "1"

    ad = make_dep "a", "= 1"
    bd = make_dep "b", "= 1"
    cd = make_dep "c", "= 1"

    deps = [ad, bd]

    s = set(a, b, c)

    res = Gem::DependencyResolver.new(s, deps)

    assert_set [a, b, c], res.resolve!
  end

  def test_picks_highest_version
    a1 = util_spec "a", '1'
    a2 = util_spec "a", '2'

    s = set(a1, a2)

    ad = make_dep "a"

    res = Gem::DependencyResolver.new(s, [ad])

    assert_set [a2], res.resolve!
  end

  def test_only_returns_spec_once
    a1 = util_spec "a", "1", "c" => "= 1"
    b1 = util_spec "b", "1", "c" => "= 1"

    c1 = util_spec "c", "1"

    ad = make_dep "a"
    bd = make_dep "b"

    s = set(a1, b1, c1)

    res = Gem::DependencyResolver.new(s, [ad, bd])

    assert_set [a1, b1, c1], res.resolve!
  end

  def test_picks_lower_version_when_needed
    a1 = util_spec "a", "1", "c" => ">= 1"
    b1 = util_spec "b", "1", "c" => "= 1"

    c1 = util_spec "c", "1"
    c2 = util_spec "c", "2"

    ad = make_dep "a"
    bd = make_dep "b"

    s = set(a1, b1, c1, c2)

    res = Gem::DependencyResolver.new(s, [ad, bd])

    assert_set [a1, b1, c1], res.resolve!

    cons = res.conflicts

    assert_equal 1, cons.size
    con = cons.first

    assert_equal "c (= 1)", con.dependency.to_s
    assert_equal "c-2", con.activated.full_name
  end

  def test_conflict_resolution_only_effects_correct_spec
    a1 = util_spec "a", "1", "c" => ">= 1"
    b1 = util_spec "b", "1", "d" => ">= 1"

    d3 = util_spec "d", "3", "c" => "= 1"
    d4 = util_spec "d", "4", "c" => "= 1"

    c1 = util_spec "c", "1"
    c2 = util_spec "c", "2"

    ad = make_dep "a"
    bd = make_dep "b"

    s = set(a1, b1, d3, d4, c1, c2)

    res = Gem::DependencyResolver.new(s, [ad, bd])

    assert_set [a1, b1, c1, d4], res.resolve!

    cons = res.conflicts

    assert_equal 1, cons.size
    con = cons.first

    assert_equal "c (= 1)", con.dependency.to_s
    assert_equal "c-2", con.activated.full_name
  end

  def test_raises_dependency_error
    a1 = util_spec "a", "1", "c" => "= 1"
    b1 = util_spec "b", "1", "c" => "= 2"

    c1 = util_spec "c", "1"
    c2 = util_spec "c", "2"

    ad = make_dep "a"
    bd = make_dep "b"

    s = set(a1, b1, c1, c2)

    r = Gem::DependencyResolver.new(s, [ad, bd])

    e = assert_raises Gem::DependencyResolutionError do
      r.resolve!
    end

    deps = [make_dep("c", "= 2"), make_dep("c", "= 1")]
    assert_equal deps, e.conflicting_dependencies
   
    con = e.conflict

    act = con.activated
    assert_equal "c-1", act.spec.full_name
    
    parent = act.parent
    assert_equal "a-1", parent.spec.full_name

    act = con.requester
    assert_equal "b-1", act.spec.full_name
  end

  def test_raises_when_a_gem_is_missing
    ad = make_dep "a"

    r = Gem::DependencyResolver.new(set(), [ad])

    e = assert_raises Gem::UnsatisfiableDepedencyError do
      r.resolve!
    end

    assert_equal "a (>= 0)", e.dependency.to_s
  end

  def test_raises_when_a_gem_version_is_missing
    a1 = util_spec "a", "1"

    ad = make_dep "a", "= 3"

    r = Gem::DependencyResolver.new(set(a1), [ad])

    e = assert_raises Gem::UnsatisfiableDepedencyError do
      r.resolve!
    end

    assert_equal "a (= 3)", e.dependency.to_s
  end

  def test_raises_when_possibles_are_exhausted
    a1 = util_spec "a", "1", "c" => ">= 2"
    b1 = util_spec "b", "1", "c" => "= 1"

    c1 = util_spec "c", "1"
    c2 = util_spec "c", "2"
    c3 = util_spec "c", "3"

    s = set(a1, b1, c1, c2, c3)

    ad = make_dep "a"
    bd = make_dep "b"

    r = Gem::DependencyResolver.new(s, [ad, bd])

    e = assert_raises Gem::ImpossibleDependenciesError do
      r.resolve!
    end

    assert_equal "c (>= 2)", e.dependency.to_s

    s, con = e.conflicts[0]
    assert_equal "c-3", s.full_name
    assert_equal "c (= 1)", con.dependency.to_s
    assert_equal "b-1", con.requester.full_name

    s, con = e.conflicts[1]
    assert_equal "c-2", s.full_name
    assert_equal "c (= 1)", con.dependency.to_s
    assert_equal "b-1", con.requester.full_name
  end

  def test_keeps_resolving_after_seeing_satisfied_dep
    a1 = util_spec "a", "1", "b" => "= 1", "c" => "= 1"
    b1 = util_spec "b", "1"
    c1 = util_spec "c", "1"

    ad = make_dep "a"
    bd = make_dep "b"

    s = set(a1, b1, c1)

    r = Gem::DependencyResolver.new(s, [ad, bd])

    assert_set [a1, b1, c1], r.resolve!
  end
end
