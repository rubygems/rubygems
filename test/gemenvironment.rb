# Create a test environment for gems.
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


$SAFE = 1

require 'rubygems'
require 'rubygems/installer'
require 'rubygems/builder'
require 'test/mockgemui'
require 'rake'

module TestEnvironment
  include Gem::DefaultUserInteraction

  # Create a testing environment for gems.
  def create
    Dir.chdir("test/data") do
      mkdir "lib" unless File.exists? "lib"
      open("lib/code.rb", "w") do |f|
        f.puts "CODE = 1"
      end unless File.exists? "lib/code.rb"

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
        FileUtils.rm_rf "gemhome"
        FileUtils.mkdir("gemhome")
        dest_dir = File.expand_path 'gemhome'
        dest_dir.untaint
        Gem::Installer.new("a-0.0.1.gem").install(false, dest_dir, false)
        Gem::Installer.new("a-0.0.2.gem").install(false, dest_dir, false)
        Gem::Installer.new("b-0.0.2.gem").install(false, dest_dir, false)
        Gem::Installer.new("c-1.2.gem").install(false, dest_dir, false)
      end
    end
  end
  
  extend(self)
end
