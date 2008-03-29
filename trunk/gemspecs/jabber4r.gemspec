require 'rubygems'

spec = Gem::Specification.new do |s|

  s.name = 'jabber4r'
  s.version = "0.7.0"
  s.platform = Gem::Platform::RUBY
  s.summary = "Jabber4r is a pure-Ruby Jabber client library"
  s.requirements << 'Jabber server'
  s.files = Dir.glob("lib/**/*").delete_if {|item| item.include?("CVS")}
  s.require_path = 'lib'
  s.autorequire = 'jabber4r/jabber4r'
  
  s.has_rdoc=true

  s.author = "Richard Kilmer"
  s.email = "rich@infoether.com"
  s.rubyforge_project = "jabber4r"
  s.homepage = "http://jabber4r.rubyforge.org"

end

if $0==__FILE__
  require 'rubygems/builder'
  Gem::Builder.new(spec).build
end
