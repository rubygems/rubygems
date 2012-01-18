##
# Basic OpenSSL-based package signing class.

class Gem::Security::Signer

  attr_accessor :cert_chain
  attr_accessor :key
  attr_reader :digest_algorithm

  ##
  # Creates a new signer with an RSA +key+ or path to a key, and a
  # +cert_chain+ containing X509 certificates or paths to X509 certificates.

  def initialize key, cert_chain
    @cert_chain = cert_chain
    @key        = key

    @digest_algorithm = Gem::Security::DIGEST_ALGORITHM

    @key = OpenSSL::PKey::RSA.new File.read @key if
      @key and not OpenSSL::PKey::RSA === @key

    @cert_chain = @cert_chain.compact.map do |cert|
      next cert if OpenSSL::X509::Certificate === cert

      OpenSSL::X509::Certificate.new File.read cert
    end if @cert_chain
  end

  ##
  # Sign data with given digest algorithm

  def sign data
    return unless @key

    @key.sign @digest_algorithm.new, data
  end

end

