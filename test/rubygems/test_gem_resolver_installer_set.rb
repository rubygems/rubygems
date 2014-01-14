require 'rubygems/test_case'

class TestGemResolverInstallerSet < Gem::TestCase

  def test_consider_local_eh
    set = Gem::Resolver::InstallerSet.new :remote

    refute set.consider_local?

    set = Gem::Resolver::InstallerSet.new :both

    assert set.consider_local?

    set = Gem::Resolver::InstallerSet.new :local

    assert set.consider_local?
  end

  def test_load_spec
    specs = spec_fetcher do |fetcher|
      fetcher.spec 'a', 2
      fetcher.spec 'a', 2 do |s| s.platform = Gem::Platform.local end
    end

    source = Gem::Source.new @gem_repo
    version = v 2

    set = Gem::Resolver::InstallerSet.new :remote

    spec = set.load_spec 'a', version, Gem::Platform.local, source

    assert_equal specs["a-2-#{Gem::Platform.local}"].full_name, spec.full_name
  end

end

