#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'stringio'

require 'rubygems'
require 'rubygems/format'
require "test/simple_gem"

class TestFormat < Test::Unit::TestCase

  def setup
    @simple_gem = SIMPLE_GEM
  end

  def test_garbled_gem_throws_format_exception
    e = assert_raises Gem::Package::FormatError do
      # subtly bogus input
      Gem::Format.from_io(StringIO.new(@simple_gem.upcase))
    end

    assert_equal 'No metadata found!', e.message

    e = assert_raises Gem::Package::FormatError do
      # Totally bogus input
      Gem::Format.from_io(StringIO.new(@simple_gem.reverse))
    end

    assert_equal 'No metadata found!', e.message

    e = assert_raises Gem::Package::FormatError do
      # This was intentionally screws up YAML parsing.
      Gem::Format.from_io(StringIO.new(@simple_gem.gsub(/:/, "boom")))
    end

    assert_equal 'No metadata found!', e.message
  end

  def test_passing_nonexistent_files_throws_sensible_exception
    assert_raises(Gem::Exception) {
      Gem::Format.from_file_by_path("/this/path/almost/definitely/will/not/exist")
    }
  end
end

