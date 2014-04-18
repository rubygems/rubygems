require 'rubygems/test_case'

class TestGemResolverSpecification < Gem::TestCase

  class TestSpec < Gem::Resolver::Specification
    attr_writer :source
    attr_reader :spec

    def initialize spec
      super()

      @spec = spec
    end
  end

  def test_installable_platform_eh
    a = util_spec 'a', 1

    a_spec = TestSpec.new a

    assert a_spec.installable_platform?

    b = util_spec 'a', 1 do |s|
      s.platform = Gem::Platform.new %w[cpu other_platform 1]
    end

    b_spec = TestSpec.new b

    refute b_spec.installable_platform?
  end

  def test_install
    spec_fetcher do |fetcher|
      a = fetcher.gem 'a', 1
    end

    a = util_spec 'a', 1

    a_spec = TestSpec.new a
    a_spec.source = Gem::Source.new @gem_repo

    a_spec.install({})

    assert_path_exists File.join @gemhome, 'gems', a.full_name
  end

end

