require 'test/unit'
require 'rubygems'
Gem::manage_gems

class TestBuilder < Test::Unit::TestCase
  def test_invalid_spec_does_not_build
    assert_equal 1, 0
    spec = Gem::Specification.new 
    builder = Gem::Builder.new(spec)
    assert_raises(Gem::InvalidSpecificationException) {
      builder.build
   }
  end
end
