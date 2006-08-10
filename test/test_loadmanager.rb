#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


# This test case disabled because it's incompatible with the new custom_require.rb.

require 'test/unit'
#require 'rubygems/loadpath_manager'
require 'rubygems/builder'

require 'test/gemenvironment'

class TestLoadPathManager #< Test::Unit::TestCase
  def setup
    TestEnvironment.create
    Gem.clear_paths
    Gem.use_paths("test/data/gemhome")
  end

  def teardown
    Gem.clear_paths
  end

  def test_build_paths
    assert defined?(Gem::LoadPathManager)
    Gem::LoadPathManager.build_paths
    assert_equal [
      "test/data/gemhome/gems/a-0.0.2/lib",
      "test/data/gemhome/gems/a-0.0.1/lib",
      "test/data/gemhome/gems/b-0.0.2/lib",
      "test/data/gemhome/gems/c-1.2/lib"
    ], Gem::LoadPathManager.paths
  end

  def test_search_loadpath
    assert Gem::LoadPathManager.search_loadpath("test/unit")
    assert ! Gem::LoadPathManager.search_loadpath("once_in_a_blue_moon")
  end

  def test_search_gempath
    assert Gem::LoadPathManager.search_gempath("code")
    assert ! Gem::LoadPathManager.search_gempath("once_in_a_blue_moon")
  end
end
