#!/usr/bin/env ruby

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Test GEM One"
  s.name = 'one'
  s.version = '0.0.1'
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'one'
  s.files = ['lib/one.rb', 'README.one']
  s.author = 'Jim Weirich'
  s.email = 'jim@weirichhouse.org'
  s.homepage = 'http://onestepback.org'
  s.has_rdoc = true
  s.description = "Test GEM for customer tests"
end
