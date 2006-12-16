$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'broken-build'
  s.version = "0.0.1"
  s.required_ruby_version = ">= 1.8.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "This gem demonstrates extensions that don't compile"
  s.files = Dir.glob("ext/**/*").delete_if {|item| item.include?("CVS")}
  s.require_path = 'lib'
  s.extensions << "ext/extconf.rb"
  s.bindir = "bin"
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

