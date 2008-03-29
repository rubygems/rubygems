$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'an-app'
  s.version = "0.0.3"
  s.required_ruby_version = ">= 1.8.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "This gem demonstrates executable scripts"
  s.requirements << 'a computer processor'
  s.files = Dir.glob("lib/**/*").delete_if {|item| item.include?("CVS")}
  s.files = Dir.glob("ext/**/*").delete_if {|item| item.include?("CVS")}
  s.files.concat Dir.glob("bin/**/*").delete_if {|item| item.include?("CVS")}
  s.require_path = 'lib'
  s.autorequire = 'somefunctionality'
  s.executables = ["myapp"]
  s.has_rdoc = false
  s.extensions << "ext/extconf.rb"
  #s.extra_rdoc_files = ["README", "Changes.rdoc"]
  #s.default_executable = "myapp"
  s.bindir = "bin"
  #s.signing_key = '/Users/chadfowler/cvs/rubygems/gem-private_key.pem'
  #s.cert_chain  = ['/Users/chadfowler/cvs/rubygems/gem-public_cert.pem']
end

if $0==__FILE__
  require 'rubygems/builder'
  Gem::Builder.new(spec).build
end

