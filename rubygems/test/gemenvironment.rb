# Create a test environment for gems.

require 'rubygems'
require 'rubygems/installer'
require 'test/mockgemui'

module TestEnvironment
  include Gem::DefaultUserInteraction

  # Create a testing environment for gems.
  def create
    return if File.exist? "test/data/gemhome/gems/a-0.0.1"
    Dir.chdir("test/data") do
      mkdir "lib" unless File.exists? "lib"
      open("lib/code.rb", "w") do |f| f.puts "CODE = 1" end unless
	File.exists? "lib/code.rb"
      spec = Gem::Specification.new do |s|
	s.files = ['lib/code.rb']
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
	spec.name = 'c'
	spec.version = '1.2'
	Gem::Builder.new(spec).build
	FileUtils.mkdir("gemhome") unless File.exist? "gemhome"
	Gem::Installer.new("a-0.0.1.gem").install(false, "gemhome", false)
	Gem::Installer.new("a-0.0.2.gem").install(false, "gemhome", false)
	Gem::Installer.new("b-0.0.2.gem").install(false, "gemhome", false)
	Gem::Installer.new("c-1.2.gem").install(false, "gemhome", false)
      end
    end
  end
  
  extend(self)
end
