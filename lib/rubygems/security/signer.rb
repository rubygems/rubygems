##
# Basic OpenSSL-based package signing class.

class Gem::Security::Signer

  attr_accessor :cert_chain
  attr_accessor :key
  attr_reader :digest_algorithm

  ##
  # Creates a new signer with an RSA +key+ or path to a key, and a certificate
  # +chain+ containing X509 certificates, encoding certificates or paths to
  # certificates.

  def initialize key, cert_chain
    @cert_chain = cert_chain
    @key        = key

    @digest_algorithm = Gem::Security::DIGEST_ALGORITHM

    @key = OpenSSL::PKey::RSA.new File.read @key if
      @key and not OpenSSL::PKey::RSA === @key

    @cert_chain = @cert_chain.compact.map do |cert|
      next cert if OpenSSL::X509::Certificate === cert

      cert = File.read cert if File.exist? cert

      OpenSSL::X509::Certificate.new cert
    end if @cert_chain
  end

  ##
  # Sign data with given digest algorithm

  def sign data
    return unless @key

    if @cert_chain.length == 1 and @cert_chain.last.not_before < Time.now then
      re_sign_key
    end

    Gem::Security::SigningPolicy.verify @cert_chain, @key

    @key.sign @digest_algorithm.new, data
  end

  ##
  # Attempts to re-sign the private key if the signing certificate is expired.
  #
  # The key will be re-signed if:
  # * The expired certificate is self-signed
  # * The expired certificate is saved at ~/.gem/gem-public_cert.pem
  # * There is no file matching the expiry date at
  #   ~/.gem/gem-public_cert.pem.expired.%Y%m%d%H%M%S
  #
  # If the signing certificate can be re-signed the expired certificate will
  # be saved as ~/.gem/gem-pubilc_cert.pem.expired.%Y%m%d%H%M%S where the
  # expiry time (not after) is used for the timestamp.

  def re_sign_key # :nodoc:
    old_cert = @cert_chain.last

    disk_cert_path = File.join Gem.user_home, 'gem-public_cert.pem'
    disk_cert = File.read disk_cert_path rescue nil
    disk_key  =
      File.read File.join(Gem.user_home, 'gem-private_key.pem') rescue nil

    if disk_key == @key.to_pem and disk_cert == old_cert.to_pem then
      expiry = old_cert.not_after.strftime '%Y%m%d%H%M%S'
      old_cert_file = "gem-public_cert.pem.expired.#{expiry}"
      old_cert_path = File.join Gem.user_home, old_cert_file

      unless File.exist? old_cert_path then
        Gem::Security.write old_cert, old_cert_path

        cert = Gem::Security.re_sign old_cert, @key

        Gem::Security.write cert, disk_cert_path

        @cert_chain = [cert]
      end
    end
  end

end

