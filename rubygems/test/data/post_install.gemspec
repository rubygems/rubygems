# -*- ruby -*-

require 'rubygems'

spec = Gem::Specification.new do |s|

  s.name = 'PostMessage'
  s.version = "0.0.1"
  s.summary = "Test for post install messages with gems."

  s.author = "Geoffrey Grosenbach"
  s.email = "no@example.com"
  s.post_install_message = "I am a shiny gem!"
end

if $0 == __FILE__
  Gem.manage_gems
  Gem::Builder.new(spec).build
end
