#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rbconfig'
require 'rubygems'

class TestDataDir < RubyGemTestCase

  def test_original_dir
    datadir = Config::CONFIG['datadir']
    assert_equal "#{datadir}/xyz", Config.gem_original_datadir('xyz')
  end

  def test_gem_dir_with_good_package
    Dir.chdir @tempdir do
      FileUtils.mkdir_p 'data'
      File.open File.join('data', 'foo.txt'), 'w' do |fp|
        fp.puts 'blah'
      end

      foo = quick_gem 'foo' do |s| s.files = %w[data/foo.txt] end
      install_gem foo
    end

    gem 'foo'
    assert_match %r{gems/foo-0.0.2/data/foo$}, Gem.datadir('foo')
  end

  def test_gem_dir_with_bad_package
    assert_nil Gem.datadir('xyzzy')
  end

  def test_basic_dir
    datadir = Config::CONFIG['datadir']
    assert_equal "#{datadir}/xyz", Config.datadir('xyz')
  end
end
