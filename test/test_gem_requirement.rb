require "minitest/autorun"
require "support/shortcuts"
require "rubygems/requirement"

class TestGemRequirement < MiniTest::Unit::TestCase
  include Support::Shortcuts

  def test_equals2
    r = req "= 1.2"
    assert_equal r, r.dup
    assert_equal r.dup, r

    refute_requirement_equal "= 1.2", "= 1.3"
    refute_requirement_equal "= 1.3", "= 1.2"

    refute_equal Object.new, req("= 1.2")
    refute_equal req("= 1.2"), Object.new
  end

  def test_initialize
    assert_requirement_equal "= 2", "2"
    assert_requirement_equal "= 2", ["2"]
    assert_requirement_equal "= 2", v(2)
  end

  def test_parse
    assert_equal ['=', Gem::Version.new(1)], Gem::Requirement.parse('  1')
    assert_equal ['=', Gem::Version.new(1)], Gem::Requirement.parse('= 1')
    assert_equal ['>', Gem::Version.new(1)], Gem::Requirement.parse('> 1')
    assert_equal ['=', Gem::Version.new(1)], Gem::Requirement.parse("=\n1")

    assert_equal ['=', Gem::Version.new(2)],
      Gem::Requirement.parse(Gem::Version.new('2'))
  end

  def test_parse_bad
    e = assert_raises ArgumentError do
      Gem::Requirement.parse nil
    end

    assert_equal 'Illformed requirement [nil]', e.message

    e = assert_raises ArgumentError do
      Gem::Requirement.parse ""
    end

    assert_equal 'Illformed requirement [""]', e.message
  end

  def test_satisfied_by_eh_bang_equal
    r = req '!= 1.2'

    assert_satisfied_by nil,   r
    assert_satisfied_by "1.1", r
    refute_satisfied_by "1.2", r
    assert_satisfied_by "1.3", r
  end

  def test_satisfied_by_eh_blank
    r = req "1.2"

    refute_satisfied_by nil,   r
    refute_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    refute_satisfied_by "1.3", r
  end

  def test_satisfied_by_eh_equal
    r = req "= 1.2"

    refute_satisfied_by nil,   r
    refute_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    refute_satisfied_by "1.3", r
  end

  def test_satisfied_by_eh_gt
    r = req "> 1.2"

    refute_satisfied_by "1.1", r
    refute_satisfied_by "1.2", r
    assert_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  def test_satisfied_by_eh_gte
    r = req ">= 1.2"

    refute_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    assert_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  def test_satisfied_by_eh_list
    r = req "> 1.1", "< 1.3"

    refute_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    refute_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  def test_satisfied_by_eh_lt
    r = req "< 1.2"

    assert_satisfied_by "1.1", r
    refute_satisfied_by "1.2", r
    refute_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  def test_satisfied_by_eh_lte
    r = req "<= 1.2"

    assert_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    refute_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  def test_satisfied_by_eh_tilde_gt
    r = req "~> 1.2"

    refute_satisfied_by "1.1", r
    assert_satisfied_by "1.2", r
    assert_satisfied_by "1.3", r

    assert_raises NoMethodError do
      r.satisfied_by? nil
    end
  end

  # Assert that two requirements are equal. Handles Gem::Requirements,
  # strings, arrays, numbers, and versions.

  def assert_requirement_equal expected, actual
    assert_equal req(expected), req(actual)
  end

  # Assert that +version+ satisfies +requirement+.

  def assert_satisfied_by version, requirement
    assert req(requirement).satisfied_by?(v(version)),
      "#{requirement} is satisfied by #{version}"
  end

  # Refute the assumption that two requirements are equal.

  def refute_requirement_equal unexpected, actual
    refute_equal req(unexpected), req(actual)
  end

  # Refute the assumption that +version+ satisfies +requirement+.

  def refute_satisfied_by version, requirement
    refute req(requirement).satisfied_by?(v(version)),
      "#{requirement} is not satisfied by #{version}"
  end
end
