#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems'
require 'test/mockgemui'
Gem.manage_gems

class TestGemLoadPaths < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    create_gemhome
    Gem.clear_paths
    Gem.use_paths("test/data/gemhome")
  end

  def test_all_load_paths
    assert_equal [
      "test/data/gemhome/gems/a-0.0.1/lib",
      "test/data/gemhome/gems/a-0.0.2/lib",
      "test/data/gemhome/gems/b-0.0.2/lib"].sort,
      Gem.all_load_paths.sort
  end

  def test_latest_load_paths
    assert_equal [
      "test/data/gemhome/gems/a-0.0.2/lib",
      "test/data/gemhome/gems/b-0.0.2/lib"].sort,
      Gem.latest_load_paths.sort
  end

  def create_gemhome
    return if File.exist? "test/data/gemhome/gems/a-0.0.1"
    Dir.chdir("test/data") do
      spec = Gem::Specification.new do |s|
	s.files = []
	s.name = "a"
	s.version = "0.0.1"
	s.summary = "summary"
	s.description = "desc"
	s.require_path = 'lib'
      end
      use_ui(MockGemUi.new) do
	Gem::Builder.new(spec).build
	spec.version = "0.0.2"
	Gem::Builder.new(spec).build
	spec.name = 'b'
	Gem::Builder.new(spec).build
	FileUtils.mkdir("gemhome") unless File.exist? "gemhome"
	Gem::Installer.new("a-0.0.1.gem").install(false, "gemhome", false)
	Gem::Installer.new("a-0.0.2.gem").install(false, "gemhome", false)
	Gem::Installer.new("b-0.0.2.gem").install(false, "gemhome", false)
      end
    end
  end
  
end
