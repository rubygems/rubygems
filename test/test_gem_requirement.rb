require 'test/unit'
require 'test/gemutilities'

class TestGemRequirement < RubyGemTestCase

  def test_satisfied_by_eh
    ver = Gem::Version.new '0.0.0'
    req = Gem::Requirement.new '>= 0'

    assert_equal true, req.satisfied_by?(ver)
  end

end

