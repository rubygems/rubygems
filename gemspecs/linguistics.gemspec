$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'Linguistics'
  s.version = "1.0.2"
  s.author = "Michael Granger, Martin Chase"
  s.email = "ged@FaerieMUD.org, stillflame@FaerieMUD.org" 
  s.homepage = "http://www.deveiate.org/code/linguistics.html"
  s.platform = Gem::Platform::RUBY
  s.summary = "This is a generic, language-neutral framework for extending Ruby objects  with linguistic methods."
  s.files = Dir.glob("{experiments,tests,redist,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.files.concat ["utils.rb", "test.rb"]
  s.require_path = 'lib'
  s.autorequire = 'linguistics'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

