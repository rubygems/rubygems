require 'rubygems/test_case'
require 'rubygems/spec_fetcher'

class TestGemSpecFetcher < Gem::TestCase

  def tuple(*args)
    Gem::NameTuple.new(*args)
  end

  def setup
    super

    @uri = URI.parse @gem_repo

    util_setup_fake_fetcher

    @a_pre = new_spec 'a', '1.a'

    install_specs @a_pre

    Gem::Specification.remove_spec @b2

    all = Gem::Specification.map { |spec|
      Gem::NameTuple.new(spec.name, spec.version, spec.original_platform)
    }.sort

    @prerelease_specs, @specs = all.partition { |g| g.prerelease? }

    # TODO: couldn't all of this come from the fake spec fetcher?
    @latest_specs = Gem::Specification.latest_specs.sort.map { |spec|
      Gem::NameTuple.new(spec.name, spec.version, spec.original_platform)
    }

    v = Gem.marshal_version
    s_zip = util_gzip(Marshal.dump(Gem::NameTuple.to_basic(@specs)))
    l_zip = util_gzip(Marshal.dump(Gem::NameTuple.to_basic(@latest_specs)))
    p_zip = util_gzip(Marshal.dump(Gem::NameTuple.to_basic(@prerelease_specs)))
    @fetcher.data["#{@gem_repo}specs.#{v}.gz"]            = s_zip
    @fetcher.data["#{@gem_repo}latest_specs.#{v}.gz"]     = l_zip
    @fetcher.data["#{@gem_repo}prerelease_specs.#{v}.gz"] = p_zip

    @sf = Gem::SpecFetcher.new

    @released = Gem::NameTuple.from_list \
                 [["a",      Gem::Version.new("1"),   "ruby"],
                  ["a",      Gem::Version.new("2"),   "ruby"],
                  ["a_evil", Gem::Version.new("9"),   "ruby"],
                  ["c",      Gem::Version.new("1.2"), "ruby"],
                  ['dep_x',  Gem::Version.new(1),     'ruby'],
                  ["pl",     Gem::Version.new("1"),   "i386-linux"],
                  ['x',  Gem::Version.new(1),     'ruby']]
  end

  def test_spec_for_dependency_all
    d = "#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}"
    @fetcher.data["#{d}#{@a1.spec_name}.rz"]    = util_zip(Marshal.dump(@a1))
    @fetcher.data["#{d}#{@a2.spec_name}.rz"]    = util_zip(Marshal.dump(@a2))
    @fetcher.data["#{d}#{@a_pre.spec_name}.rz"] = util_zip(Marshal.dump(@a_pre))
    @fetcher.data["#{d}#{@a3a.spec_name}.rz"]   = util_zip(Marshal.dump(@a3a))

    dep = Gem::Dependency.new 'a', ">= 1"

    specs_and_sources, e = @sf.spec_for_dependency dep

    spec_names = specs_and_sources.map do |spec, source_uri|
      [spec.full_name, source_uri]
    end

    expected = [[@a1.full_name, @gem_repo], [@a2.full_name, @gem_repo]]

    assert_equal expected, spec_names

    assert_same specs_and_sources.first.last, specs_and_sources.last.last
  end

  def test_spec_for_dependency_latest
    d = "#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}"
    @fetcher.data["#{d}#{@a1.spec_name}.rz"]    = util_zip(Marshal.dump(@a1))
    @fetcher.data["#{d}#{@a2.spec_name}.rz"]    = util_zip(Marshal.dump(@a2))
    @fetcher.data["#{d}#{@a_pre.spec_name}.rz"] = util_zip(Marshal.dump(@a_pre))

    dep = Gem::Dependency.new 'a'
    specs_and_sources, e = @sf.spec_for_dependency dep

    spec_names = specs_and_sources.map do |spec, source_uri|
      [spec.full_name, source_uri]
    end

    assert_equal [[@a2.full_name, @gem_repo]], spec_names
  end

  def test_spec_for_dependency_prerelease
    d = "#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}"
    @fetcher.data["#{d}#{@a1.spec_name}.rz"]    = util_zip(Marshal.dump(@a1))
    @fetcher.data["#{d}#{@a2.spec_name}.rz"]    = util_zip(Marshal.dump(@a2))
    @fetcher.data["#{d}#{@a_pre.spec_name}.rz"] = util_zip(Marshal.dump(@a_pre))

    specs_and_sources, e = @sf.spec_for_dependency dep('a', '1.a')

    spec_names = specs_and_sources.map do |spec, source_uri|
      [spec.full_name, source_uri]
    end

    assert_equal [[@a_pre.full_name, @gem_repo]], spec_names
  end

  def test_spec_for_dependency_platform
    util_set_arch 'i386-linux'

    @fetcher.data["#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}#{@pl1.original_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@pl1))

    dep = Gem::Dependency.new 'pl', 1
    specs_and_sources, e = @sf.spec_for_dependency dep

    spec_names = specs_and_sources.map do |spec, source_uri|
      [spec.full_name, source_uri]
    end

    assert_equal [[@pl1.full_name, @gem_repo]], spec_names
  end

  def test_spec_for_dependency_mismatched_platform
    util_set_arch 'hrpa-989'

    @fetcher.data["#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}#{@pl1.original_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@pl1))

    dep = Gem::Dependency.new 'pl', 1
    specs_and_sources, errors = @sf.spec_for_dependency dep

    assert_equal 0, specs_and_sources.size
    assert_equal 1, errors.size

    assert_equal "i386-linux", errors[0].platforms.first
  end

  def test_fetch_spec
    spec_uri = "#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}#{@a1.spec_name}"
    @fetcher.data["#{spec_uri}.rz"] = util_zip(Marshal.dump(@a1))

    spec = @sf.fetch_spec tuple('a', Gem::Version.new(1), 'ruby'), @uri
    assert_equal @a1.full_name, spec.full_name

    cache_dir = @sf.cache_dir URI.parse(spec_uri)

    cache_file = File.join cache_dir, @a1.spec_name

    assert File.exist?(cache_file)
  end

  def test_fetch_spec_cached
    spec_uri = "#{@gem_repo}/#{Gem::MARSHAL_SPEC_DIR}#{@a1.spec_name}"
    @fetcher.data["#{spec_uri}.rz"] = nil

    cache_dir = @sf.cache_dir URI.parse(spec_uri)
    FileUtils.mkdir_p cache_dir

    cache_file = File.join cache_dir, @a1.spec_name

    open cache_file, 'wb' do |io|
      Marshal.dump @a1, io
    end

    spec = @sf.fetch_spec tuple('a', Gem::Version.new(1), 'ruby'), @uri
    assert_equal @a1.full_name, spec.full_name
  end

  def test_fetch_spec_platform
    @fetcher.data["#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}#{@pl1.original_name}.gemspec.rz"] =
      util_zip(Marshal.dump(@pl1))

    spec = @sf.fetch_spec tuple('pl', Gem::Version.new(1), 'i386-linux'), @uri

    assert_equal @pl1.full_name, spec.full_name
  end

  def test_fetch_spec_platform_ruby
    @fetcher.data["#{@gem_repo}#{Gem::MARSHAL_SPEC_DIR}#{@a1.spec_name}.rz"] =
      util_zip(Marshal.dump(@a1))

    spec = @sf.fetch_spec tuple('a', Gem::Version.new(1), nil), @uri
    assert_equal @a1.full_name, spec.full_name

    spec = @sf.fetch_spec tuple('a', Gem::Version.new(1), ''), @uri
    assert_equal @a1.full_name, spec.full_name
  end

  def test_available_specs_latest
    specs = @sf.available_specs(:latest)

    assert_equal [@uri], specs.keys
    assert_equal @latest_specs, specs[@uri].sort
  end

  def test_available_specs_released
    specs = @sf.available_specs(:released)

    assert_equal [@uri], specs.keys

    assert_equal @released, specs[@uri].sort
  end

  def test_available_specs_complete
    specs = @sf.available_specs(:complete)

    assert_equal [@uri], specs.keys

    comp = @prerelease_specs + @released

    assert_equal comp.sort, specs[@uri].sort
  end

  def test_available_specs_cache
    specs = @sf.available_specs(:latest)

    refute specs[@uri].empty?

    @fetcher.data["#{@gem_repo}/latest_specs.#{Gem.marshal_version}.gz"] = nil

    cached_specs = @sf.available_specs(:latest)

    assert_equal specs, cached_specs
  end

  def test_available_specs_cache_released
    specs = @sf.available_specs(:released)

    refute specs[@uri].empty?

    @fetcher.data["#{@gem_repo}/specs.#{Gem.marshal_version}.gz"] = nil

    cached_specs = @sf.available_specs(:released)

    assert_equal specs, cached_specs
  end

  def test_available_specs_prerelease
    specs = @sf.available_specs(:prerelease)

    assert_equal @prerelease_specs, specs[@uri].sort
  end

  def test_load_specs
    expected = @released
    assert_equal expected, @sf.load_specs(@uri, 'specs')

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com%80'
    assert File.exist?(cache_dir), "#{cache_dir} does not exist"

    cache_file = File.join cache_dir, "specs.#{Gem.marshal_version}"
    assert File.exist?(cache_file)
  end

  def test_load_specs_cached
    # Make sure the cached version is actually different:
    @latest_specs << Gem::NameTuple.new('cached', Gem::Version.new('1.0.0'), 'ruby')

    @fetcher.data["#{@gem_repo}latest_specs.#{Gem.marshal_version}.gz"] = nil
    @fetcher.data["#{@gem_repo}latest_specs.#{Gem.marshal_version}"] =
      ' ' * Marshal.dump(@latest_specs).length

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com%80'

    FileUtils.mkdir_p cache_dir

    cache_file = File.join cache_dir, "latest_specs.#{Gem.marshal_version}"

    open cache_file, 'wb' do |io|
      Marshal.dump @latest_specs, io
    end

    latest_specs = @sf.load_specs @uri, 'latest_specs'

    assert_equal @latest_specs, latest_specs
  end

  def test_load_specs_cached_empty
    # Make sure the cached version is actually different:
    @latest_specs << Gem::NameTuple.new('fixed', Gem::Version.new('1.0.0'), 'ruby')
    # Setup valid data on the 'remote'
    @fetcher.data["#{@gem_repo}latest_specs.#{Gem.marshal_version}.gz"] =
          util_gzip(Marshal.dump(@latest_specs))

    cache_dir = File.join Gem.user_home, '.gem', 'specs', 'gems.example.com%80'

    FileUtils.mkdir_p cache_dir

    cache_file = File.join cache_dir, "latest_specs.#{Gem.marshal_version}"

    open cache_file, 'wb' do |io|
      # Setup invalid data in the cache:
      io.write Marshal.dump(@latest_specs)[0, 10]
    end

    latest_specs = @sf.load_specs @uri, 'latest_specs'

    assert_equal @latest_specs, latest_specs
  end

  def test_cache_dir_escapes_windows_paths
    uri = URI.parse("file:///C:/WINDOWS/Temp/gem_repo")
    cache_dir = @sf.cache_dir(uri).gsub(@sf.dir, '')
    assert cache_dir !~ /:/, "#{cache_dir} should not contain a :"
  end
end

