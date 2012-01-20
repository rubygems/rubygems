class Gem::Security::TrustDir

  DEFAULT_PERMISSIONS = {
    :trust_dir    => 0700,
    :trusted_cert => 0600,
  }

  def initialize dir, permissions = DEFAULT_PERMISSIONS
    @dir = dir
    @permissions = permissions

    @digester = Gem::Security::DIGEST_ALGORITHM
  end

  attr_reader :dir

  ##
  # Returns the path to the trusted +certificate+

  def cert_path certificate
    digest = @digester.hexdigest certificate.subject.to_s

    File.join @dir, "cert-#{digest}.pem"
  end

  ##
  # Add a certificate to trusted certificate list.

  def trust_cert certificate
    verify

    destination = cert_path certificate

    open destination, 'wb', @permissions[:trusted_cert] do |io|
      io.write certificate.to_pem
    end
  end

  ##
  # Enumerates trusted certificates.

  def each_certificate
    return enum_for __method__ unless block_given?

    glob = File.join @dir, '*.pem'

    Dir[glob].each do |certificate_file|
      begin
        pem = File.read certificate_file

        certificate = OpenSSL::X509::Certificate.new pem

        yield certificate, certificate_file
      rescue OpenSSL::X509::CertificateError
        next # HACK warn
      end
    end
  end

  ##
  # Make sure the trust directory exists.  If it does exist, make sure it's
  # actually a directory.  If not, then create it with the appropriate
  # permissions.

  def verify
    if File.exist? @dir then
      raise Gem::Security::Exception,
        "trust directory #{@dir} is not a directory" unless
          File.directory? @dir

      FileUtils.chmod 0700, @dir
    else
      FileUtils.mkdir_p @dir, :mode => @permissions[:trust_dir]
    end
  end

end

