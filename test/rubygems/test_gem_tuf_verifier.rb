require 'rubygems/test_case'
require 'rubygems/tuf'

unless defined?(OpenSSL::SSL) then
  warn 'Skipping Gem::TUF::Signer tests.  openssl not found.'
end

class TestGemTUFVerifier < Gem::TestCase
  def setup
    super

    @signable = {
                  "signed" => {
                    "_type"   => "Example",
                    "version" => 1
                  }
                }
  end

  def test_initialize
    Gem::TUF::Verifier.new([PRIVATE_KEY.public_key])
  end

  def test_verify
    signed_json = Gem::TUF::Signer.new(PRIVATE_KEY).sign(@signable)
    verifier = Gem::TUF::Verifier.new([PRIVATE_KEY.public_key], 1)
    json = verifier.verify(signed_json)

    assert_equal "Example", json["_type"]
  end
end if defined?(OpenSSL::SSL)

