##
# Basic OpenSSL-based package signing class.

class Gem::Security::Signer

  attr_accessor :cert_chain
  attr_accessor :key
  attr_reader :digest_algorithm

  def initialize key, cert_chain
    @digest_algorithm = Gem::Security::OPT[:dgst_algo]
    @key, @cert_chain = key, cert_chain

    # check key, if it's a file, and if it's key, leave it alone
    if @key && !@key.kind_of?(OpenSSL::PKey::PKey)
      @key = OpenSSL::PKey::RSA.new(File.read(@key))
    end

    # check cert chain, if it's a file, load it, if it's cert data, convert
    # it into a cert object, and if it's a cert object, leave it alone
    if @cert_chain
      @cert_chain = @cert_chain.map do |cert|
        # check cert, if it's a file, load it, if it's cert data, convert it
        # into a cert object, and if it's a cert object, leave it alone
        if cert && !cert.kind_of?(OpenSSL::X509::Certificate)
          cert = File.read(cert) if File::exist?(cert)
          cert = OpenSSL::X509::Certificate.new(cert)
        end
        cert
      end
    end
  end

  ##
  # Sign data with given digest algorithm

  def sign data
    return unless @key

    @key.sign @digest_algorithm.new, data
  end

end

