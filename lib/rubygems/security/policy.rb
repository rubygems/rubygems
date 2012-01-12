##
# A Gem::Security::Policy object encapsulates the settings for verifying
# signed gem files.  This is the base class.  You can either declare an
# instance of this or use one of the preset security policies below.

class Gem::Security::Policy

  attr_reader :name

  attr_accessor :only_signed
  attr_accessor :only_trusted
  attr_accessor :verify_chain
  attr_accessor :verify_data
  attr_accessor :verify_root
  attr_accessor :verify_signer

  ##
  # Create a new Gem::Security::Policy object with the given mode and
  # options.

  def initialize(name, policy = {}, opt = {})
    @name = name

    # set options
    @opt = opt

    # build policy
    policy.each_pair do |key, val|
      case key
      when :verify_data   then @verify_data   = val
      when :verify_signer then @verify_signer = val
      when :verify_chain  then @verify_chain  = val
      when :verify_root   then @verify_root   = val
      when :only_trusted  then @only_trusted  = val
      when :only_signed   then @only_signed   = val
      end
    end
  end

  ##
  # Get the path to the file for this cert.

  def self.trusted_cert_path(cert, opt = {})
    opt = Gem::Security::OPT.merge(opt)

    # get digest algorithm, calculate checksum of root.subject
    algo = opt[:dgst_algo]
    dgst = algo.hexdigest(cert.subject.to_s)

    # build path to trusted cert file
    name = "cert-#{dgst}.pem"

    # join and return path components
    File.join(opt[:trust_dir], name)
  end

  ##
  # Verify that the gem data with the given signature and signing chain
  # matched this security policy at the specified time.

  def verify_signature signature, data, chain, time = Time.now
    Gem.ensure_ssl_available
    cert_class = OpenSSL::X509::Certificate
    exc = Gem::Security::Exception
    chain ||= []

    chain = chain.map{ |str| cert_class.new(str) }
    signer, ch_len = chain[-1], chain.size
    opt = Gem::Security::OPT.merge(@opt)

    # make sure signature is valid
    if @verify_data
      # get digest algorithm (TODO: this should be configurable)
      dgst = opt[:dgst_algo]

      # verify the data signature (this is the most important part, so don't
      # screw it up :D)
      v = signer.public_key.verify(dgst.new, signature, data)
      raise exc, "Invalid Gem Signature" unless v

      # make sure the signer is valid
      if @verify_signer
        # make sure the signing cert is valid right now
        v = signer.check_validity(nil, time)
        raise exc, "Invalid Signature: #{v[:desc]}" unless v[:is_valid]
      end
    end

    # make sure the certificate chain is valid
    if @verify_chain
      # iterate down over the chain and verify each certificate against it's
      # issuer
      (ch_len - 1).downto(1) do |i|
        issuer, cert = chain[i - 1, 2]
        v = cert.check_validity(issuer, time)
        raise exc, "%s: cert = '%s', error = '%s'" % [
            'Invalid Signing Chain', cert.subject, v[:desc]
        ] unless v[:is_valid]
      end

      # verify root of chain
      if @verify_root
        # make sure root is self-signed
        root = chain[0]
        raise exc, "%s: %s (subject = '%s', issuer = '%s')" % [
            'Invalid Signing Chain Root',
            'Subject does not match Issuer for Gem Signing Chain',
            root.subject.to_s,
            root.issuer.to_s,
        ] unless root.issuer.to_s == root.subject.to_s

        # make sure root is valid
        v = root.check_validity(root, time)
        raise exc, "%s: cert = '%s', error = '%s'" % [
            'Invalid Signing Chain Root', root.subject, v[:desc]
        ] unless v[:is_valid]

        # verify that the chain root is trusted
        if @only_trusted
          # get digest algorithm, calculate checksum of root.subject
          algo = opt[:dgst_algo]
          path = Gem::Security::Policy.trusted_cert_path(root, opt)

          # check to make sure trusted path exists
          raise exc, "%s: cert = '%s', error = '%s'" % [
              'Untrusted Signing Chain Root',
              root.subject.to_s,
              "path \"#{path}\" does not exist",
          ] unless File.exist?(path)

          # load calculate digest from saved cert file
          save_cert = OpenSSL::X509::Certificate.new(File.read(path))
          save_dgst = algo.digest(save_cert.public_key.to_s)

          # create digest of public key
          pkey_str = root.public_key.to_s
          cert_dgst = algo.digest(pkey_str)

          # now compare the two digests, raise exception
          # if they don't match
          raise exc, "%s: %s (saved = '%s', root = '%s')" % [
              'Invalid Signing Chain Root',
              "Saved checksum doesn't match root checksum",
              save_dgst, cert_dgst,
          ] unless save_dgst == cert_dgst
        end
      end

      # return the signing chain
      chain.map { |cert| cert.subject }
    end
  end

  ##
  # Verifies +digests+ match +signatures+

  def verify_signatures spec, digests, signatures
    if only_signed and signatures.empty? then
      raise Gem::Security::Exception,
        "unsigned gems are not allowed by the #{name} policy"
    end

    digests.each do |file, digest|
      signature = signatures[file]
      raise Gem::Security::Exception, "missing signature for #{file}" unless
      signature
      verify_signature signature, digest.digest, spec.cert_chain
    end
  end

  alias to_s name # :nodoc:

end

