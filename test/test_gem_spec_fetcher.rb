require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/spec_fetcher'

class TestGemSpecFetcher < RubyGemTestCase

  def setup
    super

    @uri = URI.parse @gem_repo

    util_setup_fake_fetcher

    @source_index.add_spec @pl1

    @specs = @source_index.map do |name, spec|
      [spec.name, spec.version, spec.original_platform]
    end

    @fetcher.data["#{@gem_repo}/specs.#{Gem.marshal_version}.gz"] =
      util_gzip(Marshal.dump(@specs))

    @latest_specs = @source_index.latest_specs.map do |spec|
      [spec.name, spec.version, spec.original_platform]
    end

    @fetcher.data["#{@gem_repo}/latest_specs.#{Gem.marshal_version}.gz"] =
      util_gzip(Marshal.dump(@latest_specs))

    @sf = Gem::SpecFetcher.new
  end

  def test_fetch_all
    @fetcher.data["#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@a1.full_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@a1))
    @fetcher.data["#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@a2.full_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@a2))

    dep = Gem::Dependency.new 'a', 1
    specs = @sf.fetch dep, true

    assert_equal [@uri], specs.map { |uri,| uri }

    spec_names = specs.assoc(@uri).last.map { |spec| spec.full_name }
    assert_equal [@a1.full_name, @a2.full_name], spec_names
  end

  def test_fetch_latest
    @fetcher.data["#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@a1.full_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@a1))
    @fetcher.data["#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@a2.full_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@a2))

    dep = Gem::Dependency.new 'a', 1
    specs = @sf.fetch dep

    assert_equal [@uri], specs.map { |uri,| uri }

    spec_names = specs.assoc(@uri).last.map { |spec| spec.full_name }
    assert_equal [@a2.full_name], spec_names
  end

  def test_fetch_platform
    util_set_arch 'i386-linux'

    @fetcher.data["#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@pl1.original_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@pl1))

    dep = Gem::Dependency.new 'pl', 1
    specs = @sf.fetch dep

    assert_equal [@uri], specs.map { |uri,| uri }

    spec_names = specs.assoc(@uri).last.map { |spec| spec.full_name }
    assert_equal [@pl1.full_name], spec_names
  end

  def test_find_matching_all
    dep = Gem::Dependency.new 'a', 1
    specs = @sf.find_matching dep, true

    assert_equal [@uri], specs.keys

    expected = [
      ['a', Gem::Version.new(1), Gem::Platform::RUBY],
      ['a', Gem::Version.new(2), Gem::Platform::RUBY],
    ]

    assert_equal expected, specs[@uri]
  end

  def test_find_matching_latest
    dep = Gem::Dependency.new 'a', 1
    specs = @sf.find_matching dep

    assert_equal [@uri], specs.keys

    expected = [
      ['a', Gem::Version.new(2), Gem::Platform::RUBY],
    ]

    assert_equal expected, specs[@uri]
  end

  def test_find_matching_platform
    util_set_arch 'i386-linux'

    dep = Gem::Dependency.new 'pl', 1
    specs = @sf.find_matching dep

    assert_equal [@uri], specs.keys

    expected = [
      ['pl', Gem::Version.new(1), 'i386-linux'],
    ]

    assert_equal expected, specs[@uri]
  end

  def test_list_all
    specs = @sf.list true

    assert_equal [@uri], specs.keys

    expected = [
      ['a',      Gem::Version.new(1),     Gem::Platform::RUBY],
      ['a',      Gem::Version.new(2),     Gem::Platform::RUBY],
      ['a_evil', Gem::Version.new(9),     Gem::Platform::RUBY],
      ['c',      Gem::Version.new('1.2'), Gem::Platform::RUBY],
      ['pl',     Gem::Version.new(1),     'i386-linux'],
    ]

    assert_equal expected, specs[@uri].sort

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com:80'
    assert File.exist?(cache_dir)

    cache_file = File.join cache_dir, "specs.#{Gem.marshal_version}"
    assert File.exist?(cache_file)
  end

  def test_list_cache
    specs = @sf.list

    assert !specs[@uri].empty?

    @fetcher.data["#{@gem_repo}/latest_specs.#{Gem.marshal_version}.gz"] = nil

    specs = @sf.list
  end

  def test_list_disk_cache
    @fetcher.data["#{@gem_repo}/latest_specs.#{Gem.marshal_version}.gz"] = nil
    @fetcher.data["#{@gem_repo}/latest_specs.#{Gem.marshal_version}"] =
      ' ' * Marshal.dump(@latest_specs).length

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com:80'

    FileUtils.mkdir_p cache_dir

    cache_file = File.join cache_dir, "latest_specs.#{Gem.marshal_version}"

    open cache_file, 'wb' do |io|
      Marshal.dump @latest_specs, io
    end

    specs = @sf.list

    assert !specs[@uri].empty?
  end

  def test_list_latest
    specs = @sf.list

    assert_equal [@uri], specs.keys

    expected = [
      ['a',      Gem::Version.new(2),     Gem::Platform::RUBY],
      ['a_evil', Gem::Version.new(9),     Gem::Platform::RUBY],
      ['c',      Gem::Version.new('1.2'), Gem::Platform::RUBY],
      ['pl',     Gem::Version.new(1),     'i386-linux'],
    ]

    assert_equal expected, specs[@uri].sort

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com:80'
    assert File.exist?(cache_dir)

    cache_file = File.join cache_dir, "latest_specs.#{Gem.marshal_version}"
    assert File.exist?(cache_file)
  end

end

