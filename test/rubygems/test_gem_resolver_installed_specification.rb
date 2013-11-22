require 'rubygems/test_case'

class TestGemResolverInstalledSpecification < Gem::TestCase

  def test_initialize
    set     = Gem::Resolver::CurrentSet.new

    source_spec = util_spec 'a'

    spec = Gem::Resolver::InstalledSpecification.new set, source_spec

    assert_equal 'a',                 spec.name
    assert_equal Gem::Version.new(2), spec.version
    assert_equal Gem::Platform::RUBY, spec.platform
  end

  def test_installable_platform_eh
    set     = Gem::Resolver::CurrentSet.new

    b, b_gem = util_gem 'a', 1 do |s|
      s.platform = Gem::Platform.new %w[cpu other_platform 1]
    end

    source = Gem::Source::SpecificFile.new b_gem

    b_spec = Gem::Resolver::InstalledSpecification.new set, b, source

    assert b_spec.installable_platform?
  end


end

