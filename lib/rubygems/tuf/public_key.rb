##
# Representation of an RSA public key and its ID as used by TUF

class Gem::TUF::PublicKey
  attr_reader :keyid, :rsa_key

  def initialize rsa_key
    raise TypeError, "expecting a #{Gem::TUF::KEY_ALGORITHM}, got #{rsa_key.class}" unless rsa_key.is_a? Gem::TUF::KEY_ALGORITHM
    raise TypeError, "ZOMG! #{Gem::TUF::KEY_ALGORITHM} is a private key!!!" if rsa_key.private?

    @rsa_key = rsa_key
    generate_keyid
  end

  def verify signature, data
    @rsa_key.verify(Gem::TUF::DIGEST_ALGORITHM.new, signature, data)
  end

  def as_json
    {
      "keytype" => "rsa",
      "keyval"  => {
        "private" => "",
        "public"  => rsa_key.to_pem
      }
    }
  end

  private

  def generate_keyid
    canonical_json = CanonicalJSON.dump as_json
    @keyid = Digest::SHA256.hexdigest canonical_json
  end
end
