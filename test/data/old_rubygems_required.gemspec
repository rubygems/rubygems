# -*- ruby -*-

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'old_rubygems_required'
  s.version = "0.0.1"
  s.summary = "Test for required_rubygems_version."

  s.author = "Eric Hodel"
  s.email = "nobody@example.com"

  s.required_rubygems_version = '= 0.1.0'
end

if $0 == __FILE__
  require 'rubygems/builder'
  Gem::Builder.new(spec).build
end
