# frozen_string_literal: true
require 'rubygems/test_case'

class TestGemInstallerSet < Gem::TestCase

  def setup
    super
    @installer_set = Gem::Resolver::InstallerSet.new 'remote'
    @g_dep = Gem::Dependency.new('g', '>= 0')
  end

  ##
  # platform specific gem is not compatible with ruby version,
  # should select 2.0 with ruby platform
  # many pre-compiled gems have this problem after new Ruby releases

  def test_ruby_version_platform
    spec_fetcher do |fetcher|
      fetcher.gem 'g', 2.0 do |s|
        s.platform = Gem::Platform.local
        s.required_ruby_version = Gem::Requirement.new "< 2.5.0"
      end
      fetcher.gem 'g', 2.0
    end

    util_set_RUBY_VERSION '2.5.0'

    spec = @installer_set.add_always_install @g_dep

    assert_equal 1, spec.length
    assert_equal 'g-2.0', spec[0].full_name
  ensure
    util_restore_RUBY_VERSION
  end

  ##
  # 3.0 is not compatible with ruby version, should select 2.0
  # issue occurs when new gem releases drop support for older Ruby versions
  # examples rails, did_you_mean

  def test_ruby_version_gem_version
    spec_fetcher do |fetcher|
      fetcher.gem 'g', 3.0 do |s|
        s.required_ruby_version = Gem::Requirement.new ">= 2.5.0"
      end
      fetcher.gem 'g', 2.0
    end

    util_set_RUBY_VERSION '2.4.0'

    spec = @installer_set.add_always_install @g_dep

    assert_equal 1, spec.length
    assert_equal 'g-2.0', spec[0].full_name
  ensure
    util_restore_RUBY_VERSION
  end
end
