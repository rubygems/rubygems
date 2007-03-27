#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'rubygems'
Gem::manage_gems
require 'test/mockgemui'

class TestBuilder < Test::Unit::TestCase
  def setup
    @ui = MockGemUi.new
    Gem::DefaultUserInteraction.ui = @ui
  end
  
  def test_valid_specification_builds_successfully
    spec = Gem::Specification.load(File.join(File.dirname(__FILE__), '/data/post_install.gemspec'))
    builder = Gem::Builder.new(spec)
    assert_nothing_raised {
      builder.build
    }
    assert_match(/Successfully built RubyGem\n  Name: PostMessage/, @ui.output)
  end
  
  def test_invalid_spec_does_not_build
    spec = Gem::Specification.new 
    builder = Gem::Builder.new(spec)
    assert_raises(Gem::InvalidSpecificationException) {
      builder.build
   }
  end
end
