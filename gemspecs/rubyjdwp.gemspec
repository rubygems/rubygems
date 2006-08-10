$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'RubyJDWP'
  s.version = "0.0.1"
  s.author = "Rich Kilmer, Chad Fowler"
  s.email = "rich@infoether.com, chad@chadfowler.com"
  s.homepage = "http://rubyforge.org/projects/rubyjdwp"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby implementation of the Java Debug Wire Protocol. This version is pre-alpha."
  s.files = Dir.glob("{examples,lib,doc}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.require_path = 'lib'
  s.autorequire = 'jdi'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

