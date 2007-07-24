#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/builder'

class TestBuilder < RubyGemTestCase
  def setup
    super

    @ui = MockGemUi.new
  end

  def test_valid_specification_builds_successfully
    spec_path = File.join File.dirname(__FILE__), 'data', 'post_install.gemspec'

    spec = Gem::Specification.load spec_path

    builder = Gem::Builder.new spec

    assert_nothing_raised do
      use_ui @ui do
        Dir.chdir @tempdir do
          builder.build
        end
      end
    end

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
