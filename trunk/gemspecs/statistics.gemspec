$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'statistics'
  s.version = "2001.2.28"
  s.author = "Gotoken"
  s.email = "gotoken@notwork.org"
  s.homepage = "http://www.notwork.org/~gotoken/ruby/p/statistics/"
  s.platform = Gem::Platform::RUBY
  s.summary = "module Math::Statistics provides common statistical functions"
  s.files = Dir.glob("{sample,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.require_path = 'lib'
  s.autorequire = 'math/statistics'
end

if $0==__FILE__
  require 'rubygems/builder'
  Gem::Builder.new(spec).build
end

