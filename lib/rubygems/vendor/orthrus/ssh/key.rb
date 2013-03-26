module Gem::Orthrus::SSH
  class Key
    def initialize(k, digest)
      @key = k
      @digest = digest
      @comment = nil
      @source = nil
    end

    attr_reader :key
    attr_accessor :comment, :source

    def rsa?
      @key.kind_of? OpenSSL::PKey::RSA
    end

    def dsa?
      @key.kind_of? OpenSSL::PKey::DSA
    end

    def fingerprint
      blob = public_identity(false)
      OpenSSL::Digest::MD5.hexdigest(blob).scan(/../).join(":")
    end

    def inspect
      "#<#{self.class} #{fingerprint}>"
    end

    def ==(o)
      return false unless o.kind_of? Orthrus::SSH::Key
      @key.to_pem == o.key.to_pem
    end
  end

  class PrivateKey < Key
    def sign(data, b64armor=false)
      s = @key.sign @digest.new, data
      b64armor ? Utils.encode64(s) : s
    end
  end

  class PublicKey < Key
    def verify(sign, data, b64armor=false)
      sign = Utils.decode64 sign if b64armor
      @key.verify @digest.new, sign, data
    end
  end

end
