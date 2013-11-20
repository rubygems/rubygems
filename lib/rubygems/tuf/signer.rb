# TODO: remove this dependency somehow
require 'json'

##
# Produce signed JSON documents in The Update Framework (TUF) format

class Gem::TUF::Signer
  def initialize keyid, key
    raise TypeError, "expecting a #{KEY_ALGORITHM}" unless key.is_a? Gem::TUF::KEY_ALGORITHM
    @keyid, @key = keyid, key
  end

  def sign json
    signed = json['signed']
    raise ArgumentError, "no data to sign" unless signed
    raise ArgumentError, "expected 'signed' to contain '_type'" unless signed['_type']

    to_sign = CanonicalJSON.dump(signed)

    signature = @key.sign(Gem::TUF::DIGEST_ALGORITHM.new, to_sign)

    signatures = json['signatures'] ||= []
    signatures << {
      "keyid"  => @keyid,
      "method" => "RSASSA-PKCS#1-v1.5+SHA512",
      "sig"    => signature.unpack("H*").first
    }

    json
  end
end
