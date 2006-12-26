#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'rubygems/dependency_list'
require 'rubygems/specification'

class TestDependencyList < Test::Unit::TestCase
  def setup
    @deplist = Gem::DependencyList.new
  end

  def test_create
    assert @deplist.ok?, "all dependencies should be satisfied"
  end

  def test_one_unsatisfied_gem
    @deplist.add(bspec)
    assert ! @deplist.ok?
  end

  def test_one_satisfied_gem
    @deplist.add(create_spec("a", "1.1"))
    assert @deplist.ok?
  end

  def test_two_gems_with_dependency
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(bspec)
    assert @deplist.ok?
  end

  def test_removing_required_gem
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(bspec)
    a = @deplist.remove_by_name("a-1.1")
    assert ! @deplist.ok?
  end

  def test_removing_redundent_gem
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(create_spec("a", "1.3"))
    @deplist.add(bspec)
    a = @deplist.remove_by_name("a-1.1")
    assert @deplist.ok?
  end

  def test_finding_gems
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(bspec)
    assert_equal "a-1.1", @deplist.find_name("a-1.1").full_name
    assert_equal "b-1.2", @deplist.find_name("b-1.2").full_name
    assert_nil @deplist.find_name("c-1.2")
  end

  def test_ok_to_remove
    @deplist.add(create_spec("a", "1.1"))
    assert @deplist.ok_to_remove?("a-1.1")
  end

  def test_not_ok_to_remove
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(bspec)
    assert ! @deplist.ok_to_remove?("a-1.1")
  end

  def test_ok_to_remove_with_extras
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(create_spec("a", "1.2"))
    @deplist.add(bspec)
    assert @deplist.ok_to_remove?("a-1.1")
    assert @deplist.ok_to_remove?("a-1.2")
    assert @deplist.ok_to_remove?("b-1.2")
  end

  def test_not_ok_to_remove_after_sibling_removed
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(create_spec("a", "1.2"))
    @deplist.add(bspec)
    assert @deplist.ok_to_remove?("a-1.1")
    assert @deplist.ok_to_remove?("a-1.2")
    @deplist.remove_by_name("a-1.1")
    assert ! @deplist.ok_to_remove?("a-1.2")
  end

  def test_sorting
    @deplist.add(create_spec("a", "1.1"))
    @deplist.add(bspec)
    @deplist.add(create_spec("a", "1.3"))
    order = @deplist.dependency_order
    assert_equal "b-1.2", order.first.full_name
  end

  def test_sorting_four_with_out_ambiguities
    @deplist.add(Gem::Specification.new do |s|
        s.name = "a"
        s.version = '1.1'
      end)
    @deplist.add(Gem::Specification.new do |s|
        s.name = "b"
        s.version = '1.1'
        s.add_dependency("a", ">= 1.1")
      end)
    @deplist.add(Gem::Specification.new do |s|
        s.name = "c"
        s.version = '1.1'
        s.add_dependency("b", ">= 1.1")
      end)
    @deplist.add(Gem::Specification.new do |s|
        s.name = "d"
        s.version = '1.1'
        s.add_dependency("c", ">= 1.1")
      end)
    order = @deplist.dependency_order
    assert_equal ['d', 'c', 'b', 'a'], order.collect { |s| s.name }
  end

  def test_sorting_with_circular_dependency
    @deplist.add(Gem::Specification.new do |s|
        s.name = "a"
        s.version = '1.1'
        s.add_dependency("c", ">= 1.1")
      end)
    @deplist.add(Gem::Specification.new do |s|
        s.name = "b"
        s.version = '1.1'
        s.add_dependency("a", ">= 1.1")
      end)
    @deplist.add(Gem::Specification.new do |s|
        s.name = "c"
        s.version = '1.1'
        s.add_dependency("b", ">= 1.1")
      end)
    order = @deplist.dependency_order
  end

  def test_from_source_index
    hash = {
      'a-1.1' => create_spec("a", "1.1"),
      'b-1.2' => bspec,
    }
    si = Gem::SourceIndex.new(hash)
    deps = Gem::DependencyList.from_source_index(si)
    assert_equal ['b-1.2', 'a-1.1'],
      deps.dependency_order.collect { |s| s.full_name }
  end

  # ------------------------------------------------------------------

  def bspec
    Gem::Specification.new do |s|
      s.name = "b"
      s.version = "1.2"
      s.add_dependency("a", ">= 1.1")
    end
  end

  def create_spec(name, version)
    Gem::Specification.new do |s|
      s.name = name
      s.version = version
    end
  end
end
