require 'rubygems'
Gem::manage_gems
require 'test/unit'
require 'stringio'

class TestFormat < Test::Unit::TestCase
  def setup
    require File.dirname(__FILE__) + "/simple_gem.rb"
    @simple_gem = SIMPLE_GEM
  end

  def test_from_io_returns_format_object
    format = Gem::Format.from_io(StringIO.new(@simple_gem))

    assert_equal(Gem::Format, format.class)
    assert_equal(Gem::Specification, format.spec.class) 
    # simple_gem.rb's gem has 3 files in it
    assert_equal(3, format.file_entries.size)
  end

  def test_garbled_gem_throws_format_exception
    assert_raises(Gem::FormatException) {
      # subtly bogus input
      Gem::Format.from_io(StringIO.new(@simple_gem.upcase))
    }
    assert_raises(Gem::FormatException) {
      # Totally bogus input
      Gem::Format.from_io(StringIO.new(@simple_gem.reverse))
    }
    assert_raises(Gem::FormatException) {
      # This was intentionally screws up YAML parsing.
      Gem::Format.from_io(StringIO.new(@simple_gem.gsub(/:/, "boom")))
    }
  end

  def test_passing_nonexistent_files_throws_sensible_exception
    assert_raises(Gem::FormatException) {
      Gem::Format.from_file_by_path("/this/path/almost/definitely/will/not/exist")
    }
  end
end
