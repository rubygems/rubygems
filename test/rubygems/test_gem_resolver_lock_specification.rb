require 'rubygems/test_case'
require 'rubygems/resolver'

class TestGemResolverLockSpecification < Gem::TestCase

  def setup
    super

    @LS = Gem::Resolver::LockSpecification

    @source = Gem::Source.new @gem_repo
    @set    = Gem::Resolver::LockSet.new @source
  end

  def test_initialize
    spec = @LS.new @set, 'a', v(2), @source, Gem::Platform::RUBY

    assert_equal 'a',                 spec.name
    assert_equal v(2),                spec.version
    assert_equal Gem::Platform::RUBY, spec.platform

    assert_equal @source, spec.source
  end

  def test_dependencies_equals
    l_spec = @LS.new @set, 'a', v(2), @source, Gem::Platform::RUBY

    l_spec.dependencies = [
      dep('b', '>= 0'),
      dep('c', '~> 1'),
    ]

    expected = [
      dep('b', '>= 0'),
      dep('c', '~> 1'),
    ]

    assert_equal expected, l_spec.dependencies
  end

  def test_install
    spec = @LS.new @set, 'a', v(2), @source, Gem::Platform::RUBY

    called = false

    spec.install({}) do |installer|
      called = installer
    end

    assert_nil called
  end

  def test_spec
    version = v(2)

    l_spec = @LS.new @set, 'a', version, @source, Gem::Platform::RUBY

    l_spec.dependencies = [
      dep('b', '>= 0'),
      dep('c', '~> 1'),
    ]

    spec = l_spec.spec

    assert_equal 'a',                 spec.name
    assert_equal version,             spec.version
    assert_equal Gem::Platform::RUBY, spec.platform

    expected = [
      dep('b', '>= 0'),
      dep('c', '~> 1'),
    ]

    assert_equal expected, l_spec.spec.dependencies
  end

end

