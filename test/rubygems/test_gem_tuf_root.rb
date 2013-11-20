require 'rubygems/test_case'
require 'rubygems/tuf'

unless defined?(OpenSSL::SSL) then
  warn 'Skipping Gem::TUF::Root tests.  openssl not found.'
end

class TestGemTUFRoot < Gem::TestCase
  def setup
    super
    @root_keys  = [PRIVATE_KEY.public_key]
    @threshhold = 1

    signer = Gem::TUF::Signer.new PRIVATE_KEY

    # TODO: lol this is all wrong but it's a start
    unsigned_root_txt = {"signed"=>{"_type"=>"Root", "expires"=>"2013-11-19T13:58:12-08:00", "keys"=>{"abc123"=>{"keytype"=>"md5lol", "keyval"=>{"private"=>"", "public"=>"asdfasdfsadfsadlkfjsad"}}}, "roles"=>{"release"=>{"keyids"=>["abc123"], "threshold"=>1}, "root"=>{"keyids"=>["abc123"], "threshold"=>1}, "targets"=>{"keyids"=>["abc123"], "threshold"=>1}, "timestamp"=>{"keyids"=>["abc123"], "threshold"=>1}}}}
    @root_txt = signer.sign(unsigned_root_txt)
  end

  def test_initialize
    root = Gem::TUF::Root.new(@root_txt, @root_keys)
  end
end if defined?(OpenSSL::SSL)

