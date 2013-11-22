require 'rubygems/test_case'
require 'rubygems/available_set'

class TestGemResolverLocalSpecification < Gem::TestCase

  def setup
    super

    @set = Gem::AvailableSet.new
  end

  def test_installable_platform_eh
    b, b_gem = util_gem 'a', 1 do |s|
      s.platform = Gem::Platform.new %w[cpu other_platform 1]
    end

    source = Gem::Source::SpecificFile.new b_gem

    b_spec = Gem::Resolver::InstalledSpecification.new @set, b, source

    assert b_spec.installable_platform?
  end

end

