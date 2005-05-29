#!/usr/bin/env ruby

require 'fileutils'
require 'test/unit/testcase'
require 'tmpdir'
require 'test/yaml_data'

module Utilities
  def make_cache_area(path, *uris)
    fn = File.join(path, 'source_cache')
    open(fn, 'w') do |f| f.write Marshal.dump(cache_hash(*uris)) end
  end

  extend self
end

class RubyGemTestCase < Test::Unit::TestCase
  def setup
    @tempdir = File.join Dir.tmpdir, "test_rubygems_#{$$}"
    @gemhome = File.join @tempdir, "gemhome"
    @gemcache = File.join(@gemhome, "source_cache")
    @usrcache = File.join(@gemhome, ".gem", "user_cache")

    FileUtils.mkdir_p @gemhome

    ENV['GEMCACHE'] = @usrcache
    Gem.use_paths(@gemhome)
  end

  def teardown
    FileUtils.rm_r @tempdir
    ENV['GEMCACHE'] = nil
    Gem.clear_paths
  end

  def prep_cache_files(lc)
    [ [lc.system_cache_file, 'sys'],
      [lc.user_cache_file, 'usr'],
    ].each do |fn, data|
      FileUtils.mkdir_p File.dirname(fn)
      open(fn, "w") { |f| f.puts(Marshal.dump({'key' => data})) }
    end
  end

  def read_cache(fn)
    open(fn) { |f| Marshal.load(f) }
  end

  def write_file(path)
    path = File.join(@gemhome, path)
    dir = File.dirname path
    FileUtils.mkdir_p dir
    File.open(path, "w") { |io|
      yield(io)
    }
  end

  def quick_gem(gemname, version='0.0.2')
    spec = Gem::Specification.new do |s|
      s.platform = Gem::Platform::RUBY
      s.name = gemname
      s.version = version
      s.author = 'A User'
      s.email = 'example@example.com'
      s.homepage = 'http://example.com'
      s.has_rdoc = true
      s.summary = "this is a summary"
      s.description = "This is a test description"
      yield(s)
    end

    write_file(File.join("specifications", spec.full_name + ".gemspec")) do |io|
      io.write(spec.to_ruby)
    end

    return spec
  end

  def test_stupid
    # shuts up test/unit
  end
end
