require 'rubygems/test_case'
require 'rubygems/tuf'

unless defined?(OpenSSL::SSL) then
  warn 'Skipping Gem::TUF::Root tests.  openssl not found.'
end

class TestGemTUFRoot < Gem::TestCase
  ROOT_PUBLIC_KEY = tuf_cert("root-public")
  ROOT_FILE       = File.read(tuf_file("root.txt"))

  def test_initialize
    Gem::TUF::Root.new ROOT_FILE
  end
end if defined?(OpenSSL::SSL)

