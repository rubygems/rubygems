require 'test/unit'
require 'rubygems'

class TestBuilder < Test::Unit::TestCase
  def test_invalid_spec_does_not_build
    spec = Gem::Specification.new 
    builder = Gem::Builder.new(spec)
    assert_raises(Gem::InvalidSpecificationException) {
      builder.build
   }
  end
end
