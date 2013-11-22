# TODO: remove this dependency somehow
require 'json'

##
# Produce signed JSON documents in The Update Framework (TUF) format

class Gem::TUF::Signer
  attr_reader :rsa_key

  def initialize rsa_key
    raise TypeError, "expecting a #{KEY_ALGORITHM}" unless rsa_key.is_a? Gem::TUF::KEY_ALGORITHM
    raise TypeError, "#{KEY_ALGORITHM} is not a private key" unless rsa_key.private?

    @rsa_key = rsa_key
  end

  def sign json
    signed = json['signed']
    raise ArgumentError, "no data to sign" unless signed
    raise ArgumentError, "expected 'signed' to contain '_type'" unless signed['_type']

    to_sign = CanonicalJSON.dump(signed)

    signature = @rsa_key.sign(Gem::TUF::DIGEST_ALGORITHM.new, to_sign)

    signatures = json['signatures'] ||= []
    signatures << {
      "keyid"  => Gem::TUF::PublicKey.new(@rsa_key.public_key).keyid,
      "method" => "RSASSA-PKCS#1-v1.5+SHA512",
      "sig"    => signature.unpack("H*").first
    }

    json
  end
end
