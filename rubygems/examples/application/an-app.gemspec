$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'an-app'
  s.version = "0.0.2"
  s.platform = Gem::Platform::RUBY
  s.summary = "This gem demonstrates executable scripts"
  s.requirements << 'a computer processor'
  s.files = Dir.glob("lib/**/*").delete_if {|item| item.include?("CVS")}
  s.files.concat Dir.glob("bin/**/*").delete_if {|item| item.include?("CVS")}
  s.require_path = 'lib'
  s.autorequire = 'somefunctionality'
  s.executables = ["myapp"]
  s.extra_rdoc_files = ["README", "Changes.rdoc"]
  #s.default_executable = "myapp"
  s.bindir = "bin"
end

if $0==__FILE__
  Gem::Builder.new(spec).build
end

