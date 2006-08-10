#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'rubygems'
require 'test/mockgemui'
require 'test/gemenvironment'

Gem.manage_gems

class TestGemLoadPaths < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    TestEnvironment.create
    Gem.clear_paths
    Gem.use_paths("test/data/gemhome")
  end

  def test_all_load_paths
    assert_equal [
      "test/data/gemhome/gems/a-0.0.1/lib",
      "test/data/gemhome/gems/a-0.0.2/lib",
      "test/data/gemhome/gems/b-0.0.2/lib",
      "test/data/gemhome/gems/c-1.2/lib"].sort,
      Gem.all_load_paths.sort
  end

  def test_latest_load_paths
    assert_equal [
      "test/data/gemhome/gems/a-0.0.2/lib",
      "test/data/gemhome/gems/b-0.0.2/lib",
      "test/data/gemhome/gems/c-1.2/lib"].sort,
      Gem.latest_load_paths.sort
  end

  def test_required_location
    assert_equal "test/data/gemhome/gems/c-1.2/lib/code.rb",
      Gem.required_location("c", "code.rb")
    assert_equal "test/data/gemhome/gems/a-0.0.1/lib/code.rb",
      Gem.required_location("a", "code.rb", "<0.0.2")
    assert_equal "test/data/gemhome/gems/a-0.0.2/lib/code.rb",
      Gem.required_location("a", "code.rb", "=0.0.2")
  end

end
