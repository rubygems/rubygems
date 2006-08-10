$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'progressbar'
  s.version = "0.0.3"
  s.author = "Satoru Takabayashi"
  s.email = "satoru@namazu.org"
  s.homepage = "http://namazu.org/~satoru/ruby-progressbar/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby/ProgressBar is a text progress bar library for Ruby.  It can indicate progress with percentage, a progress bar, and estimated remaining time."
  s.files = Dir.glob("{sample,lib,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc")}
  s.files.concat ["ChangeLog"]
  s.require_path = 'lib'
  s.autorequire = 'progressbar'
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

