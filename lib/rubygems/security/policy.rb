##
# A Gem::Security::Policy object encapsulates the settings for verifying
# signed gem files.  This is the base class.  You can either declare an
# instance of this or use one of the preset security policies in
# Gem::Security::Policies.

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

  def initialize name, policy = {}, opt = {}
    @name = name

    @opt = opt

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
  #--
  # TODO move to Gem::Security

  def self.trusted_cert_path cert, opt = {}
    opt = Gem::Security::OPT.merge opt

    digester = opt[:dgst_algo]
    digest = digester.hexdigest cert.subject.to_s

    name = "cert-#{digest}.pem"

    File.join opt[:trust_dir], name
  end

  ##
  # Verifies each certificate in +chain+ has signed the following certificate
  # and is valid for the given +time+.

  def check_chain chain, time
    chain.each_cons 2 do |issuer, cert|
      check_cert cert, issuer, time
    end

    true
  rescue Gem::Security::Exception => e
    raise Gem::Security::Exception, "invalid signing chain: #{e.message}"
  end

  ##
  # Verifies that +data+ matches the +signature+ created by +public_key+ and
  # the +digest+ algorithm.

  def check_data public_key, digest, signature, data
    raise Gem::Security::Exception, "invalid signature" unless
      public_key.verify digest.new, signature, data

    true
  end

  ##
  # Ensures that +signer+ is valid for +time+ and was signed by the +issuer+.
  # If the +issuer+ is +nil+ no verification is performed.

  def check_cert signer, issuer, time
    message = "certificate #{signer.subject}"

    if not_before = signer.not_before and not_before > time then
      raise Gem::Security::Exception,
            "#{message} not valid before #{not_before}"
    end

    if not_after = signer.not_after and not_after < time then
      raise Gem::Security::Exception, "#{message} not valid after #{not_after}"
    end

    if issuer and not signer.verify issuer.public_key then
      raise Gem::Security::Exception,
            "#{message} was not issued by #{issuer.subject}"
    end

    true
  end

  ##
  # Ensures the root certificate in +chain+ is self-signed and valid for
  # +time+.

  def check_root chain, time
    root = chain.first

    raise Gem::Security::Exception,
          "root certificate #{root.subject} is not self-signed " \
          "(issuer #{root.issuer})" if
      root.issuer != root.subject

    check_cert root, root, time
  end

  def check_trust chain, digester, trust_dir
    root = chain.first

    # get digest algorithm, calculate checksum of root.subject
    path = Gem::Security::Policy.trusted_cert_path(root,
                                                   :trust_dir => trust_dir,
                                                   :digester  => digester)

    # check to make sure trusted path exists
    unless File.exist? path
      message = "root cert #{root.subject} is not trusted"

      message << " (root of signing cert #{chain.last.subject})" if
        chain.length > 1

      raise Gem::Security::Exception, message
    end

    # load calculate digest from saved cert file
    save_cert = OpenSSL::X509::Certificate.new File.read path
    save_dgst = digester.digest save_cert.public_key.to_s

    # create digest of public key
    pkey_str = root.public_key.to_s
    cert_dgst = digester.digest pkey_str

    raise Gem::Security::Exception,
          "trusted root certificate #{root.subject} checksum " \
          "does not match signing root certificate checksum" unless
      save_dgst == cert_dgst

    true
  end

  ##
  # Verify that the gem data with the given signature and signing chain
  # matched this security policy at the specified time.

  def verify_signature signature, data, chain, time = Time.now
    Gem.ensure_ssl_available
    chain ||= []

    chain = chain.map { |cert| OpenSSL::X509::Certificate.new cert }
    signer = chain.last

    opt       = Gem::Security::OPT.merge @opt
    digester  = opt[:dgst_algo]
    trust_dir = opt[:trust_dir]

    check_data signer.public_key, digester, signature, data if @verify_data

    check_cert signer, nil, time if @verify_signer

    check_chain chain, time if @verify_chain

    check_root chain, time if @verify_root

    check_trust chain, digester, trust_dir if @only_trusted

    true
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

