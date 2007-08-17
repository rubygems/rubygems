#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'test/gemutilities'
require 'rubygems/dependency_list'

class TestGemDependencyList < RubyGemTestCase

  def setup
    super

    @deplist = Gem::DependencyList.new

    @a1 = quick_gem 'a', '1'
    @a2 = quick_gem 'a', '2'
    @a3 = quick_gem 'a', '3'

    @b1 = quick_gem 'b', '1' do |s| s.add_dependency 'a', '>= 1' end
    @b2 = quick_gem 'b', '2' do |s| s.add_dependency 'a', '>= 1' end

    @c1 = quick_gem 'c', '1' do |s| s.add_dependency 'b', '>= 1' end
    @c2 = quick_gem 'c', '2'

    @d1 = quick_gem 'd', '1' do |s| s.add_dependency 'c', '>= 1' end
  end

  def test_self_from_source_index
    hash = {
      'a-1' => @a1,
      'b-2' => @b2,
    }

    si = Gem::SourceIndex.new hash
    deps = Gem::DependencyList.from_source_index si

    assert_equal %w[b-2 a-1], deps.dependency_order.map { |s| s.full_name }
  end

  def test_active_count
    assert_equal 0, @deplist.send(:active_count, [], {})
    assert_equal 1, @deplist.send(:active_count, [@a1], {})
    assert_equal 0, @deplist.send(:active_count, [@a1],
                                  { @a1.full_name => true })
  end

  def test_add
    assert_equal [], @deplist.dependency_order

    @deplist.add @a1, @b2

    assert_equal [@b2, @a1], @deplist.dependency_order
  end

  def test_build_predecessors
    expected = {}
    assert_equal expected, @deplist.send(:build_predecessors)

    @deplist.add @a1

    assert_equal expected, @deplist.send(:build_predecessors)

    @deplist.add @b1

    expected = { @a1.full_name => [@b1] }

    assert_equal expected, @deplist.send(:build_predecessors)
  end

  def test_dependency_order
    @deplist.add @a1
    @deplist.add @b1
    @deplist.add @c1
    @deplist.add @d1
    order = @deplist.dependency_order
    assert_equal %w[d c b a], order.map { |s| s.name }
  end

  def test_dependency_order_circular
    @a1.add_dependency 'c', '>= 1'

    @deplist.add @a1
    @deplist.add @b1
    @deplist.add @c1
    order = @deplist.dependency_order
    assert_equal %w[a c b], order.map { |s| s.name }
  end

  def xtest_dependency_order_diamond
    a1 = quick_gem 'a', '1'
    a2 = quick_gem 'a', '2'

    b = quick_gem 'b', '1' do |s| s.add_dependency 'a', '>= 1' end
    c = quick_gem 'c', '1' do |s| s.add_dependency 'a', '>= 1' end

    d = quick_gem 'd', '1' do |s|
      s.add_dependency 'b'
      s.add_dependency 'c'
    end

    @deplist.add a1, a2, b, c, d

    order = @deplist.dependency_order
    assert_equal %w[d b a c], order.map { |s| s.name }
  end

  def test_find_name
    @deplist.add @a1, @b2

    assert_equal "a-1", @deplist.find_name("a-1").full_name
    assert_equal "b-2", @deplist.find_name("b-2").full_name

    assert_nil @deplist.find_name("c-2")
  end

  def test_ok_eh
    assert @deplist.ok?, 'no dependencies'

    @deplist.add @b2
    assert ! @deplist.ok?, 'unsatisfied dependency'

    @deplist.add @a1
    assert @deplist.ok?, 'satisfied dependency'
  end

  def test_ok_eh_dependency_redundant
    @deplist.add @a1, @a3, @b2
    a = @deplist.remove_by_name("a-1")
    assert @deplist.ok?
  end

  def test_ok_to_remove_eh
    @deplist.add @a1
    assert @deplist.ok_to_remove?("a-1")

    @deplist.add @b2
    assert ! @deplist.ok_to_remove?("a-1")

    @deplist.add @a2
    assert @deplist.ok_to_remove?("a-1")
    assert @deplist.ok_to_remove?("a-2")
    assert @deplist.ok_to_remove?("b-2")
  end

  def test_ok_to_remove_eh_after_sibling_removed
    @deplist.add @a1, @a2, @b2

    assert @deplist.ok_to_remove?("a-1")
    assert @deplist.ok_to_remove?("a-2")

    @deplist.remove_by_name("a-1")

    assert ! @deplist.ok_to_remove?("a-2")
  end

  def test_remove_by_name
    @deplist.add @a1, @b2
    a = @deplist.remove_by_name("a-1")
    assert ! @deplist.ok?
  end

end

