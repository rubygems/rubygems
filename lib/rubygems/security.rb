#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'rubygems/gem_openssl'

module Gem
  module SSL

    # We make our own versions of the constants here.  This allows us
    # to reference the constants, even though some systems might not
    # have SSL installed in the Ruby core package.
    #
    # These constants are only used during load time.  At runtime, any
    # method that makes a direct reference to SSL software must be
    # protected with a Gem.ensure_ssl_available call.
    #
    if Gem.ssl_available?
      PKEY_RSA = OpenSSL::PKey::RSA
      DIGEST_SHA1 = OpenSSL::Digest::SHA1
    else
      PKEY_RSA = :rsa
      DIGEST_SHA1 = :sha1
    end
  end
end

module OpenSSL # :nodoc:
  module X509 # :nodoc:
    class Certificate
      #
      # Check the validity of this certificate.  
      #
      def check_validity(issuer_cert = nil, time = Time.now)
        ret = if @not_before && @not_before > time
          [false, :expired, "not valid before '#@not_before'"]
        elsif @not_after && @not_after < time
          [false, :expired, "not valid after '#@not_after'"]
        elsif issuer_cert && !verify(issuer_cert.public_key)
          [false, :issuer, "#{issuer_cert.subject} is not issuer"]
        else
          [true, :ok, 'Valid certificate']
        end

        # return hash
        { :is_valid => ret[0], :error => ret[1], :desc => ret[2] }
      end
    end
  end
end

module Gem
  #
  # Security: a set of methods, classes, and security policies for
  # checking the validity of signed gem files.
  #
  module Security
    class Exception < Exception; end
  
    #
    # default options for most of the methods below
    #
    OPT = {
      # private key options
      :key_algo   => Gem::SSL::PKEY_RSA,
      :key_size   => 2048,

      # public cert options
      :cert_age   => 365 * 24 * 3600, # 1 year
      :dgst_algo  => Gem::SSL::DIGEST_SHA1,

      # x509 certificate extensions
      :cert_exts  => {
        'basicConstraints'      => 'CA:FALSE',
        'subjectKeyIdentifier'  => 'hash',
        'keyUsage'              => 'keyEncipherment,dataEncipherment,digitalSignature',
      },

      # save the key and cert to a file in build_self_signed_cert()?
      :save_key   => true,
      :save_cert  => true,

      # if you define either of these, then they'll be used instead of
      # the output_fmt macro below
      :save_key_path => nil,
      :save_cert_path => nil,

      # output name format for self-signed certs
      :output_fmt => 'gem-%s.pem',
      :munge_re   => Regexp.new(/[^a-z0-9_.-]+/),

      # output directory for trusted certificate checksums
      :trust_dir => File::join(Gem.user_home, '.gem', 'trust'),

      # default permissions for trust directory and certs
      :perms => {
        :trust_dir      => 0700,
        :trusted_cert   => 0600,
        :signing_cert   => 0600,
        :signing_key    => 0600,
      },
    }

    #
    # A Gem::Security::Policy object encapsulates the settings for
    # verifying signed gem files.  This is the base class.  You can
    # either declare an instance of this or use one of the preset
    # security policies below.
    #
    class Policy
      attr_accessor :verify_data, :verify_signer, :verify_chain, 
                    :verify_root, :only_trusted, :only_signed

      #
      # Create a new Gem::Security::Policy object with the given mode
      # and options.
      #
      def initialize(policy = {}, opt = {})
        # set options
        @opt = Gem::Security::OPT.merge(opt)

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

      #
      # Get the path to the file for this cert.
      #
      def self.trusted_cert_path(cert, opt = {})
        opt = Gem::Security::OPT.merge(opt)

        # get digest algorithm, calculate checksum of root.subject
        algo = opt[:dgst_algo]
        dgst = algo.hexdigest(cert.subject.to_s)

        # build path to trusted cert file
        name = "cert-#{dgst}.pem"

        # join and return path components
        File::join(opt[:trust_dir], name)
      end

      #
      # Verify that the gem data with the given signature and signing
      # chain matched this security policy at the specified time.
      #
      def verify_gem(signature, data, chain, time = Time.now)
        Gem.ensure_ssl_available
        cert_class = OpenSSL::X509::Certificate
        exc = Gem::Security::Exception
        chain ||= []

        chain = chain.map{ |str| cert_class.new(str) }
        signer, ch_len = chain[-1], chain.size

        # make sure signature is valid
        if @verify_data
          # get digest algorithm (TODO: this should be configurable)
          dgst = @opt[:dgst_algo]

          # verify the data signature (this is the most important part,
          # so don't screw it up :D)
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
          # iterate down over the chain and verify each certificate
          # against it's issuer
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
              algo = @opt[:dgst_algo]
              path = Gem::Security::Policy.trusted_cert_path(root, @opt)

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
    end

    #
    # No security policy: all package signature checks are disabled.
    #
    NoSecurity = Policy.new({
      :verify_data      => false,
      :verify_signer    => false,
      :verify_chain     => false,
      :verify_root      => false,
      :only_trusted     => false,
      :only_signed      => false,
    })

    #
    # AlmostNo security policy: only verify that the signing certificate
    # is the one that actually signed the data.  Make no attempt to
    # verify the signing certificate chain.
    #
    # This policy is basically useless. better than nothing, but can still be easily
    # spoofed, and is not recommended.
    #
    AlmostNoSecurity = Policy.new({
      :verify_data      => true,
      :verify_signer    => false,
      :verify_chain     => false,
      :verify_root      => false,
      :only_trusted     => false,
      :only_signed      => false,
    })
    
    #
    # Low security policy: only verify that the signing certificate is
    # actually the gem signer, and that the signing certificate is 
    # valid.
    #
    # This policy is better than nothing, but can still be easily
    # spoofed, and is not recommended.
    #
    LowSecurity = Policy.new({
      :verify_data      => true,
      :verify_signer    => true,
      :verify_chain     => false,
      :verify_root      => false,
      :only_trusted     => false,
      :only_signed      => false,
    })
    
    #
    # Medium security policy: verify the signing certificate, verify the
    # signing certificate chain all the way to the root certificate, and
    # only trust root certificates that we have explicity allowed trust
    # for.
    #
    # This security policy is reasonable, but it allows unsigned
    # packages, so a malicious person could simply delete the package
    # signature and pass the gem off as unsigned. 
    #
    MediumSecurity = Policy.new({
      :verify_data      => true,
      :verify_signer    => true,
      :verify_chain     => true,
      :verify_root      => true,
      :only_trusted     => true,
      :only_signed      => false,
    })
    
    #
    # High security policy: only allow signed gems to be installed,
    # verify the signing certificate, verify the signing certificate
    # chain all the way to the root certificate, and only trust root
    # certificates that we have explicity allowed trust for.
    #
    # This security policy is significantly more difficult to bypass,
    # and offers a reasonable guarantee that the contents of the gem
    # have not been altered.
    #
    HighSecurity = Policy.new({
      :verify_data      => true,
      :verify_signer    => true,
      :verify_chain     => true,
      :verify_root      => true,
      :only_trusted     => true,
      :only_signed      => true,
    })
    
    #
    # Sign the cert cert with @signing_key and @signing_cert, using the
    # digest algorithm opt[:dgst_algo]. Returns the newly signed
    # certificate.
    #
    def self.sign_cert(cert, signing_key, signing_cert, opt = {})
      opt = OPT.merge(opt)

      # set up issuer information
      cert.issuer = signing_cert.subject
      cert.sign(signing_key, opt[:dgst_algo].new)

      cert
    end
    
    #
    # Make sure the trust directory exists.  If it does exist, make sure
    # it's actually a directory.  If not, then create it with the
    # appropriate permissions.
    #
    def self.verify_trust_dir(path, perms)
      # if the directory exists, then make sure it is in fact a
      # directory.  if it doesn't exist, then create it with the
      # appropriate permissions
      if File.exist?(path)
        # verify that the trust directory is actually a directory
        unless File.directory?(path)
          err = "trust directory #{path} isn't a directory"
          raise Gem::Security::Exception, err
        end
      else
        # trust directory doesn't exist, so create it with 
        # permissions
        FileUtils.mkdir_p(path)
        FileUtils.chmod(perms, path)
      end
    end

    #
    # Build a certificate from the given DN and private key.
    # 
    def self.build_cert(name, key, opt = {})
      Gem.ensure_ssl_available
      opt = OPT.merge(opt)

      # create new cert
      ret = OpenSSL::X509::Certificate.new

      # populate cert attributes
      ret.version = 2
      ret.serial = 0
      ret.public_key = key.public_key
      ret.not_before = Time.now
      ret.not_after = Time.now + opt[:cert_age]
      ret.subject = name

      # add certificate extensions
      ef = OpenSSL::X509::ExtensionFactory.new(nil, ret)
      ret.extensions = opt[:cert_exts].map { |k, v| ef.create_extension(k, v) }
        
      # sign cert
      i_key, i_cert = opt[:issuer_key] || key, opt[:issuer_cert] || ret
      ret = sign_cert(ret, i_key, i_cert, opt)
        
      # return cert
      ret
    end

    #
    # Build a self-signed certificate for the given email address.
    #
    def self.build_self_signed_cert(email_addr, opt = {})
      Gem.ensure_ssl_available
      opt = OPT.merge(opt)
      path = { :key => nil, :cert => nil }

      # split email address up
      cn, dcs = email_addr.split('@')
      dcs = dcs.split('.')

      # munge email CN and DCs
      cn = cn.gsub(opt[:munge_re], '_')
      dcs = dcs.map { |dc| dc.gsub(opt[:munge_re], '_') }
      
      # create DN
      name = "CN=#{cn}/" << dcs.map { |dc| "DC=#{dc}" }.join('/')
      name = OpenSSL::X509::Name::parse(name)

      # build private key
      key = opt[:key_algo].new(opt[:key_size])

      # method name pretty much says it all :)
      verify_trust_dir(opt[:trust_dir], opt[:perms][:trust_dir])

      # if we're saving the key, then write it out
      if opt[:save_key]
        path[:key] = opt[:save_key_path] || (opt[:output_fmt] % 'private_key')
        File.open(path[:key], 'wb') do |file| 
          file.chmod(opt[:perms][:signing_key])
          file.write(key.to_pem) 
        end
      end
      
      # build self-signed public cert from key
      cert = build_cert(name, key, opt)

      # if we're saving the cert, then write it out
      if opt[:save_cert]
        path[:cert] = opt[:save_cert_path] || (opt[:output_fmt] % 'public_cert')
        File.open(path[:cert], 'wb') do |file| 
          file.chmod(opt[:perms][:signing_cert])
          file.write(cert.to_pem)
        end
      end

      # return key, cert, and paths (if applicable)
      { :key => key, :cert => cert, 
        :key_path => path[:key], :cert_path => path[:cert] }
    end

    #
    # Add certificate to trusted cert list.
    #
    # Note: At the moment these are stored in OPT[:trust_dir], although
    # that directory may change in the future.
    #
    def self.add_trusted_cert(cert, opt = {})
      opt = OPT.merge(opt)

      # get destination path 
      path = Gem::Security::Policy.trusted_cert_path(cert, opt)

      # verify trust directory (can't write to nowhere, you know)
      verify_trust_dir(opt[:trust_dir], opt[:perms][:trust_dir])

      # write cert to output file
      File.open(path, 'wb') do |file| 
        file.chmod(opt[:perms][:trusted_cert])
        file.write(cert.to_pem)
      end

      # return nil
      nil
    end

    #
    # Basic OpenSSL-based package signing class.
    # 
    class Signer
      attr_accessor :key, :cert_chain

      def initialize(key, cert_chain)
        Gem.ensure_ssl_available
        @algo = Gem::Security::OPT[:dgst_algo]
        @key, @cert_chain = key, cert_chain
        
        # check key, if it's a file, and if it's key, leave it alone
        if @key && !@key.kind_of?(OpenSSL::PKey::PKey)
          @key = OpenSSL::PKey::RSA.new(File.read(@key))
        end

        # check cert chain, if it's a file, load it, if it's cert data, convert
        # it into a cert object, and if it's a cert object, leave it alone
        if @cert_chain
          @cert_chain = @cert_chain.map do |cert|
            # check cert, if it's a file, load it, if it's cert data,
            # convert it into a cert object, and if it's a cert object,
            # leave it alone
            if cert && !cert.kind_of?(OpenSSL::X509::Certificate)
              cert = File.read(cert) if File::exist?(cert)
              cert = OpenSSL::X509::Certificate.new(cert)
            end
            cert
          end
        end
      end

      #
      # Sign data with given digest algorithm
      #
      def sign(data)
        @key.sign(@algo.new, data)
      end

      # moved to security policy (see above)
      # def verify(sig, data)
      #  @cert.public_key.verify(@algo.new, sig, data)
      # end
    end
  end
end
