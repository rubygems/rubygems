#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'fileutils'
require 'test/unit/testcase'
require 'tmpdir'
require 'uri'
require 'rubygems/gem_open_uri'

require 'test/yaml_data'
require 'test/mockgemui'

module Utilities
  def make_cache_area(path, *uris)
    fn = File.join(path, 'source_cache')
    open(fn, 'wb') do |f| f.write Marshal.dump(cache_hash(*uris)) end
  end

  module_function :make_cache_area
end

class FakeFetcher

  attr_reader :data
  attr_accessor :uri

  def initialize
    @data = {}
    @uri = nil
  end

  def fetch_path(path)
    path = path.to_s
    raise ArgumentError, 'need full URI' unless path =~ %r'^http://'
    data = @data[path]
    raise OpenURI::HTTPError.new("no data for #{path}", nil) if data.nil?
    data.respond_to?(:call) ? data.call : data
  end

  def fetch_size(path)
    path = path.to_s
    raise ArgumentError, 'need full URI' unless path =~ %r'^http://'
    data = @data[path]
    raise OpenURI::HTTPError.new("no data for #{path}", nil) if data.nil?
    data.respond_to?(:call) ? data.call : data.length
  end

end

class RubyGemTestCase < Test::Unit::TestCase

  include Gem::DefaultUserInteraction

  undef_method :default_test

  def setup
    super
    @tempdir = File.join Dir.tmpdir, "test_rubygems_#{$$}"    
    @gemhome = File.join @tempdir, "gemhome"
    @gemcache = File.join(@gemhome, "source_cache")
    @usrcache = File.join(@gemhome, ".gem", "user_cache")

    FileUtils.mkdir_p @gemhome

    ENV['GEMCACHE'] = @usrcache
    Gem.use_paths(@gemhome)
  end

  def teardown
    if defined? Gem::RemoteFetcher then
      Gem::RemoteFetcher.instance_variable_set :@fetcher, nil
    end

    FileUtils.rm_rf @tempdir
    ENV['GEMCACHE'] = nil
    Gem.clear_paths
    Gem::SourceInfoCache.instance_variable_set :@cache, nil
  end

  def prep_cache_files(lc)
    [ [lc.system_cache_file, 'sys'],
      [lc.user_cache_file, 'usr'],
    ].each do |fn, data|
      FileUtils.mkdir_p File.dirname(fn)
      open(fn, "wb") { |f| f.write(Marshal.dump({'key' => data})) }
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
      yield(s) if block_given?
    end

    write_file(File.join("specifications", spec.full_name + ".gemspec")) do |io|
      io.write(spec.to_ruby)
    end

    return spec
  end

  def util_setup_fake_fetcher
    @uri = URI.parse 'http://gems.example.com'
    @fetcher = FakeFetcher.new
    @fetcher.uri = @uri

    @gem1 = quick_gem 'gem_one' do |gem|
      gem.files = %w[Rakefile lib/gem_one.rb]
    end

    @gem2 = quick_gem 'gem_two' do |gem|
      gem.files = %w[Rakefile lib/gem_two.rb]
    end

    @gem3 = quick_gem 'gem_three' do |gem| # missing gem
      gem.files = %w[Rakefile lib/gem_three.rb]
    end

    # this gem has a higher version and longer name than the gem we want
    @gem4 = quick_gem 'gem_one_evil', '666' do |gem|
      gem.files = %w[Rakefile lib/gem_one.rb]
    end

    gem_names = [@gem1.full_name, @gem2.full_name, @gem4.full_name]
    @gem_names = gem_names.sort.join("\n")

    @source_index = Gem::SourceIndex.new @gem1.full_name => @gem1,
                                         @gem2.full_name => @gem2,
                                         @gem4.full_name => @gem4

    Gem::RemoteFetcher.instance_variable_set :@fetcher, @fetcher
  end

  def util_setup_source_info_cache(*specs)
    specs = Hash[*specs.map { |spec| [spec.full_name, spec] }.flatten]
    si = Gem::SourceIndex.new specs

    sice = Gem::SourceInfoCacheEntry.new si, 0
    sic = Gem::SourceInfoCache.new
    sic.set_cache_data( { 'http://gems.example.com' => sice } )
    Gem::SourceInfoCache.instance_variable_set :@cache, sic
    si
  end

  def util_zip(data)
    Zlib::Deflate.deflate data
  end

  @@win_platform = nil
  def win_platform?
    if @@win_platform.nil?
      patterns = [/mswin/i, /mingw/i, /bccwin/i, /wince/i]
      @@win_platform = patterns.find{|r| RUBY_PLATFORM =~ r} ? true : false
    end
    @@win_platform
  end

end

