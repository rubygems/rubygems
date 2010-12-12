require File.expand_path('../gemutilities', __FILE__)
require "rubygems/text"

class TestGemText < RubyGemTestCase
  include Gem::Text

  def test_format_text
    assert_equal "text to\nwrap",     format_text("text to wrap", 8)
  end

  def test_format_text_indent
    assert_equal "  text to\n  wrap", format_text("text to wrap", 8, 2)
  end

  def test_format_text_none
    assert_equal "text to wrap",      format_text("text to wrap", 40)
  end

  def test_format_text_none_indent
    assert_equal "  text to wrap",    format_text("text to wrap", 40, 2)
  end
end
