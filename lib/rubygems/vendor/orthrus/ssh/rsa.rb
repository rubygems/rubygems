require 'rubygems/vendor/orthrus/ssh/key'

module Gem::Orthrus::SSH

  module RSA
    def initialize(k)
      super k, OpenSSL::Digest::SHA1
    end

    def public_identity(base64=true)
      b = Buffer.from :string, "ssh-rsa",
                      :bignum, @key.e,
                      :bignum, @key.n

      d = b.to_s

      return d unless base64

      Utils.encode64 d
    end

    def type
      "ssh-rsa"
    end
  end

  class RSAPrivateKey < PrivateKey
    include RSA
  end

  class RSAPublicKey < PublicKey
    def self.parse(data)
      raw = Utils.decode64 data

      b = Buffer.new raw

      type = b.read_string
      unless type == "ssh-rsa"
        raise "Unvalid key data"
      end

      k = OpenSSL::PKey::RSA.new
      k.e = b.read_bignum
      k.n = b.read_bignum

      new k
    end

    include RSA
  end
end
