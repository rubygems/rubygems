require 'rubygems/test_case'
require 'rubygems/tuf'

unless defined?(OpenSSL::SSL) then
  warn 'Skipping Gem::TUF::Signer tests.  openssl not found.'
end

class TestGemTUFVerifier < Gem::TestCase
  def setup
    super

    @public_key = Gem::TUF::PublicKey.new PUBLIC_KEY
    @signable = {
                  "signed" => {
                    "_type"   => "Example",
                    "version" => 1,
                    "expires" => "2038-01-19 03:14:08 UTC"
                  }
                }
  end

  def test_initialize
    Gem::TUF::Verifier.new([PRIVATE_KEY.public_key])
  end

  def test_verify
    signed_json = Gem::TUF::Signer.new(PRIVATE_KEY).sign(@signable)
    verifier = Gem::TUF::Verifier.new([@public_key], 1)
    json = verifier.verify(signed_json)

    assert_equal "Example", json["_type"]
  end

  def test_expiry_checking
    expired_signable = @signable.dup
    expired_signable['signed']['expires'] = "1970-01-01 00:00:00 UTC"

    signed_json = Gem::TUF::Signer.new(PRIVATE_KEY).sign(expired_signable)
    verifier = Gem::TUF::Verifier.new([@public_key], 1)
    assert_raises Gem::TUF::VerificationError do
      verifier.verify(signed_json)
    end
  end
end if defined?(OpenSSL::SSL)

