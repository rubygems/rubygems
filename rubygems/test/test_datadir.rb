#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'rbconfig'
require 'rubygems'

class TestDataDir < Test::Unit::TestCase
  def test_original_dir
    datadir = Config::CONFIG['datadir']
    assert_equal "#{datadir}/xyz", Config.gem_original_datadir('xyz')
  end

  def test_gem_dir_with_good_package
    gem 'sources'
    assert_match %r{gems/1.8/gems/sources-0.0.1/data/sources$}, Gem.datadir('sources')
  end

  def test_gem_dir_with_bad_package
    gem 'sources'
    assert_nil Gem.datadir('xyzzy')
  end

  def test_basic_dir
    datadir = Config::CONFIG['datadir']
    assert_equal "#{datadir}/xyz", Config.datadir('xyz')
  end
end
