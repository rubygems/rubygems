$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'rublog'
  s.version = "0.8.0"
  s.author = "Dave Thomas"
  s.email = "dave@pragprog.com"
  s.homepage = "http://www.pragprog.com/pragdave/Tech/Blog"
  s.platform = Gem::Platform::RUBY
  s.summary = "RubLog is a simple web log, based around the idea of displaying a set of regular files in a log-format."
  s.files = Dir.glob("{extras,styles,convertors,doc,data,search,sidebar}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.files.concat Dir.glob("*rb")
  s.files.concat Dir.glob("*cgi")
  s.files << "README"
  s.require_path =  "."
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

