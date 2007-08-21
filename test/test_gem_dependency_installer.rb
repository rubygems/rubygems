require 'test/unit'
require 'test/gemutilities'
require 'rubygems/dependency_installer'

class TestGemDependencyInstaller < RubyGemTestCase

  def setup
    super

    @a1, @a1_cache_file = util_gem 'a', '1'

    @b1, @b1_cache_file = util_gem 'b', '1'
    @b1.add_dependency 'a'

    @x1_m, = util_gem 'x', '1' do |s| s.platform = %w[cpu my_platform 1] end
    @x1_o, = util_gem 'x', '1' do |s| s.platform = %w[cpu other_platform 1] end
    @w1,   = util_gem 'w', '1'
    @w1.add_dependency 'x'

    @y1,     = util_gem 'y', '1'
    @y1_1_p, = util_gem 'y', '1.1' do |s| s.platform = %w[cpu my_platform 1] end
    @z1,     = util_gem 'z', '1'
    @z1.add_dependency 'y'

    si = util_setup_source_info_cache @a1, @b1, @x1_m, @x1_o, @w1,
                                      @y1, @y1_1_p, @z1

    @fetcher = FakeFetcher.new
    Gem::RemoteFetcher.instance_variable_set :@fetcher, @fetcher
    @fetcher.uri = URI.parse 'http://gems.example.com'
    @fetcher.data['http://gems.example.com/gems/yaml'] = si.to_yaml
  end

  def test_install
    inst = Gem::DependencyInstaller.new 'a'

    inst.install

    assert_equal Gem::SourceIndex.new(@a1.full_name => @a1),
                 Gem::SourceIndex.from_installed_gems

    assert_equal [@a1], inst.installed_gems
  end

  def test_install_dependency
    inst = Gem::DependencyInstaller.new 'b'

    inst.install

    assert_equal %w[b-1 a-1], inst.installed_gems.map { |s| s.full_name }
  end

  def test_download_gem
    a1_data = nil
    File.open @a1_cache_file, 'rb' do |fp|
      a1_data = fp.read
    end
    FileUtils.rm @a1_cache_file

    @fetcher.data['http://gems.example.com/gems/a-1.gem'] = a1_data

    inst = Gem::DependencyInstaller.new 'a'

    assert_equal @a1_cache_file, inst.download(@a1, 'http://gems.example.com')

    assert File.exist?(File.join(@gemhome, 'cache', "#{@a1.full_name}.gem"))
  end

  def test_download_gem_cached
    assert File.exist?(File.join(@gemhome, 'cache', "#{@a1.full_name}.gem"))

    inst = Gem::DependencyInstaller.new 'a'

    assert_equal @a1_cache_file, inst.download(@a1, 'http://gems.example.com')
  end

  def test_gather_dependencies
    inst = Gem::DependencyInstaller.new 'b'

    assert_equal %w[b-1 a-1], inst.gems_to_install.map { |s| s.full_name }
  end

  def test_gather_dependencies_platform_alternate
    util_set_target 'cpu', 'my_platform1'

    inst = Gem::DependencyInstaller.new 'w'

    assert_equal %w[w-1 x-1-cpu-my_platform-1],
                 inst.gems_to_install.map { |s| s.full_name }
  end

  def test_gather_dependencies_platform_bump
    inst = Gem::DependencyInstaller.new 'z'

    assert_equal %w[z-1 y-1], inst.gems_to_install.map { |s| s.full_name }
  end

  def util_gem(name, version, &block)
    spec = quick_gem(name, version, &block)

    util_build_gem spec

    cache_file = File.join Gem.dir, 'cache', "#{spec.full_name}.gem"
    FileUtils.rm File.join(@gemhome, 'specifications',
                           "#{spec.full_name}.gemspec")

    [spec, cache_file]
  end

end

