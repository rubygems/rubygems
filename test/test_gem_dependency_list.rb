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

    @a1_1 = quick_gem 'a', '1.1'
    @a1_2 = quick_gem 'a', '1.2'
    @a1_3 = quick_gem 'a', '1.3'

    @b1_1 = quick_gem 'b', '1.1' do |s| s.add_dependency 'a', '>= 1.1' end
    @b1_2 = quick_gem 'b', '1.2' do |s| s.add_dependency 'a', '>= 1.1' end

    @c1_1 = quick_gem 'c', '1.1' do |s| s.add_dependency 'b', '>= 1.1' end
    @c1_2 = quick_gem 'c', '1.2'

    @d1_1 = quick_gem 'd', '1.1' do |s| s.add_dependency 'c', '>= 1.1' end
  end

  def test_self_from_source_index
    hash = {
      'a-1.1' => @a1_1,
      'b-1.2' => @b1_2,
    }

    si = Gem::SourceIndex.new hash
    deps = Gem::DependencyList.from_source_index si

    assert_equal %w[b-1.2 a-1.1], deps.dependency_order.map { |s| s.full_name }
  end

  def test_dependency_order
    @deplist.add @a1_1
    @deplist.add @b1_1
    @deplist.add @c1_1
    @deplist.add @d1_1
    order = @deplist.dependency_order
    assert_equal %w[d c b a], order.map { |s| s.name }
  end

  def test_dependency_order_circular
    @a1_1.add_dependency 'c', '>= 1.1'

    @deplist.add @a1_1
    @deplist.add @b1_1
    @deplist.add @c1_1
    order = @deplist.dependency_order
    assert_equal %w[a c b], order.map { |s| s.name }
  end

  def test_find_name
    @deplist.add @a1_1
    @deplist.add @b1_2
    assert_equal "a-1.1", @deplist.find_name("a-1.1").full_name
    assert_equal "b-1.2", @deplist.find_name("b-1.2").full_name
    assert_nil @deplist.find_name("c-1.2")
  end

  def test_ok_eh
    assert @deplist.ok?, 'no dependencies'

    @deplist.add @b1_2
    assert ! @deplist.ok?, 'unsatisfied dependency'

    @deplist.add @a1_1
    assert @deplist.ok?, 'satisfied dependency'
  end

  def test_ok_eh_dependency_redundant
    @deplist.add @a1_1
    @deplist.add @a1_3
    @deplist.add @b1_2
    a = @deplist.remove_by_name("a-1.1")
    assert @deplist.ok?
  end

  def test_ok_to_remove_eh
    @deplist.add @a1_1
    assert @deplist.ok_to_remove?("a-1.1")

    @deplist.add @b1_2
    assert ! @deplist.ok_to_remove?("a-1.1")

    @deplist.add @a1_2
    assert @deplist.ok_to_remove?("a-1.1")
    assert @deplist.ok_to_remove?("a-1.2")
    assert @deplist.ok_to_remove?("b-1.2")
  end

  def test_ok_to_remove_eh_after_sibling_removed
    @deplist.add @a1_1
    @deplist.add @a1_2
    @deplist.add @b1_2

    assert @deplist.ok_to_remove?("a-1.1")
    assert @deplist.ok_to_remove?("a-1.2")

    @deplist.remove_by_name("a-1.1")

    assert ! @deplist.ok_to_remove?("a-1.2")
  end

  def test_remove_by_name
    @deplist.add @a1_1
    @deplist.add @b1_2
    a = @deplist.remove_by_name("a-1.1")
    assert ! @deplist.ok?
  end

end

