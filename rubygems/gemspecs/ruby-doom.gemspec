$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'ruby-doom'
  s.version = "0.0.7"
  s.author = "Tom Copeland"
  s.email = "tom@infoether.com"
  s.homepage = "http://ruby-doom.rubyforge.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby-DOOM provides a scripting API for creating DOOM maps. It also provides higher-level APIs to make map creation easier."
  s.files = Dir.glob("{samples,tests,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.require_path = 'lib'
  s.autorequire = 'doom'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

