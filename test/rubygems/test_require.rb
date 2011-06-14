require 'rubygems/test_case'
require 'rubygems'

class TestRequire < Gem::TestCase
  def assert_require(path)
    assert require(path), "'#{path}' was already required"
  end

  def test_require_is_not_lazy_with_exact_req
    a1 = new_spec "a", "1", {"b" => "= 1"}, "lib/a.rb"
    b1 = new_spec "b", "1", nil, "lib/b/c.rb"
    b2 = new_spec "b", "2", nil, "lib/b/c.rb"

    install_specs a1, b1, b2

    save_loaded_features do
      assert_require 'a'
      assert_equal %w(a-1 b-1), loaded_spec_names
      assert_equal unresolved_names, []

      assert_require "b/c"
      assert_equal %w(a-1 b-1), loaded_spec_names
    end
  end

  def test_require_is_lazy_with_inexact_req
    a1 = new_spec "a", "1", {"b" => ">= 1"}, "lib/a.rb"
    b1 = new_spec "b", "1", nil, "lib/b/c.rb"
    b2 = new_spec "b", "2", nil, "lib/b/c.rb"

    install_specs a1, b1, b2

    save_loaded_features do
      assert_require 'a'
      assert_equal %w(a-1), loaded_spec_names
      assert_equal unresolved_names, ["b (>= 1)"]

      assert_require "b/c"
      assert_equal %w(a-1 b-2), loaded_spec_names
    end
  end

  def test_require_is_not_lazy_with_one_possible
    a1 = new_spec "a", "1", {"b" => ">= 1"}, "lib/a.rb"
    b1 = new_spec "b", "1", nil, "lib/b/c.rb"

    install_specs a1, b1

    save_loaded_features do
      assert_require 'a'
      assert_equal %w(a-1 b-1), loaded_spec_names
      assert_equal unresolved_names, []

      assert_require "b/c"
      assert_equal %w(a-1 b-1), loaded_spec_names
    end
  end

  def test_activate_via_require_respects_loaded_files
    save_loaded_features do
      require 'benchmark' # stdlib

      a1 = new_spec "a", "1", {"b" => ">= 1"}, "lib/a.rb"
      b1 = new_spec "b", "1", nil, "lib/benchmark.rb"
      b2 = new_spec "b", "2", nil, "lib/benchmark.rb"

      install_specs a1, b1, b2

      require 'a'
      assert_equal unresolved_names, ["b (>= 1)"]

      refute require('benchmark'), "benchmark should have already been loaded"

      # We detected that we should activate b-2, so we did so, but
      # then original_require decided "I've already got benchmark.rb" loaded.
      # This case is fine because our lazy loading is provided exactly
      # the same behavior as eager loading would have.

      assert_equal %w(a-1 b-2), loaded_spec_names
    end
  end

  def test_already_activated_direct_conflict
    save_loaded_features do
      a1 = new_spec "a", "1", { "b" => "> 0" }
      b1 = new_spec "b", "1", { "c" => ">= 1" }, "lib/ib.rb"
      b2 = new_spec "b", "2", { "c" => ">= 2" }, "lib/ib.rb"
      c1 = new_spec "c", "1", nil, "lib/d.rb"
      c2 = new_spec("c", "2", nil, "lib/d.rb")

      install_specs a1, b1, b2, c1, c2

      a1.activate
      c1.activate
      assert_equal %w(a-1 c-1), loaded_spec_names
      assert_equal ["b (> 0)"], unresolved_names

      assert require("ib")

      assert_equal %w(a-1 b-1 c-1), loaded_spec_names
      assert_equal [], unresolved_names
    end
  end

  def loaded_spec_names
    Gem.loaded_specs.values.map(&:full_name).sort
  end

  def unresolved_names
    Gem::Specification.unresolved_deps.values.map(&:to_s).sort
  end

  def save_loaded_features
    old_loaded_features = $LOADED_FEATURES.dup
    yield
  ensure
    $LOADED_FEATURES.replace old_loaded_features
  end

end
