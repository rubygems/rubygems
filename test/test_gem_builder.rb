#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/builder'

class TestGemBuilder < RubyGemTestCase

  def test_build_invalid_spec
    spec = Gem::Specification.new
    builder = Gem::Builder.new(spec)
    assert_raises Gem::InvalidSpecificationException do
      builder.build
    end
  end

  def test_build_valid_spec
    spec_path = File.join File.dirname(__FILE__), 'data', 'post_install.gemspec'

    spec = Gem::Specification.load spec_path

    builder = Gem::Builder.new spec

    use_ui @ui do
      Dir.chdir @tempdir do
        builder.build
      end
    end

    assert_match(/Successfully built RubyGem\n  Name: PostMessage/, @ui.output)
  end

end

