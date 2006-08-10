$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'RedCloth'
  s.version = "2.0.2"
  s.author = "Why the Lucky Stiff"
  s.email = "why@ruby-lang.org"
  s.homepage = "http://www.whytheluckystiff.net/ruby/redcloth/"
  s.platform = Gem::Platform::RUBY
  s.summary = "RedCloth is a module for using Textile in Ruby. Textile is a text format. A very simple text format. Another stab at making readable text that can be converted to HTML."
  s.files = Dir.glob("{tests,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.files << "run-tests.rb"
  s.require_path = 'lib'
  s.autorequire = 'redcloth'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

