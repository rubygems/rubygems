$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'Ook'
  s.version = "1.0.2"
  s.author = "Chad Fowler"
  s.email = "chad@chadfowler.com"
  s.homepage = "http://www.chadfowler.com/ruby/rubyook"
  s.platform = Gem::Platform::RUBY
  s.summary = "A Ruby interpreter for the Ook! (www.dangermouse.net/esoteric/ook.html) and BrainF*ck (www.catseye.mb.ca/esoteric/bf/index.html) programming languages."
  s.files = Dir.glob("{samples,tests,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.require_path = 'lib'
  s.autorequire = 'ook'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

