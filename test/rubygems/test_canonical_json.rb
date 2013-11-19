require 'rubygems/test_case'
require 'rubygems/command'
require_relative '../../lib/rubygems/util/canonical_json'

class TestCanonicalJSON < Gem::TestCase
  def setup
    super
  end

  def test_sorted_json
    expected = %q[{"a":"b","c":"d","w":{"a":"a","x":"n"}}]
    actual = CanonicalJSON.dump({ "c" => "d", "a" => "b", "w" => { "x" => "n", "a" => "a" } })
    assert_equal expected, actual
  end

  def test_simple_case
    expected = %q[{"a":"b"}]
    actual = CanonicalJSON.dump({ :a => "b" })
    assert_equal expected, actual
  end

  def test_fixnums
    expected = %q[{"a":42}]
    actual = CanonicalJSON.dump({ "a" => 42 })
    assert_equal expected, actual
  end

  def test_newlines_in_string_value
    expected = %q[{"a":"I\nlike\rturtles!"}]
    actual = CanonicalJSON.dump({ "a" => "I\nlike\rturtles!" })
    assert_equal expected, actual
  end

  def test_array_values
    expected = %q[{"a":[1,2,3,5]}]
    actual = CanonicalJSON.dump({ "a" => [1,2,3,5] })
    assert_equal expected, actual
  end

  def test_raise_for_float
    assert_raises TypeError do
      CanonicalJSON.dump({ :a => 1.5 })
    end
  end

  def test_booleans
    expected = %q[{"a":"true"}]
    actual = CanonicalJSON.dump({ "a" => true })
    assert_equal expected, actual
  end

  def test_nil
    expected = %q[{"a":null}]
    actual = CanonicalJSON.dump({ "a" => nil })
    assert_equal expected, actual
  end
end
