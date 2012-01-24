require 'rubygems/command'
require 'rubygems/security'

class Gem::Commands::CertCommand < Gem::Command

  def initialize
    super 'cert', 'Manage RubyGems certificates and signing settings',
          :add => [], :remove => [], :list => [], :build => [], :sign => []

    OptionParser.accept OpenSSL::X509::Certificate do |certificate|
      begin
        OpenSSL::X509::Certificate.new File.read certificate
      rescue Errno::ENOENT
        raise OptionParser::InvalidArgument, "#{certificate}: does not exist"
      rescue OpenSSL::X509::CertificateError
        raise OptionParser::InvalidArgument,
          "#{certificate}: invalid X509 certificate"
      end
    end

    OptionParser.accept OpenSSL::PKey::RSA do |key_file|
      begin
        key = OpenSSL::PKey::RSA.new File.read key_file
      rescue Errno::ENOENT
        raise OptionParser::InvalidArgument, "#{key_file}: does not exist"
      rescue OpenSSL::PKey::RSAError
        raise OptionParser::InvalidArgument, "#{key_file}: invalid RSA key"
      end

      raise OptionParser::InvalidArgument,
            "#{key_file}: private key not found" unless
              key.private?

      key
    end

    add_option('-a', '--add CERT', OpenSSL::X509::Certificate,
               'Add a trusted certificate.') do |cert, options|
      options[:add] << cert
    end

    add_option('-l', '--list [FILTER]',
               'List trusted certificates where the',
               'subject contains FILTER') do |filter, options|
      filter ||= ''

      options[:list] << filter
    end

    add_option('-r', '--remove FILTER',
               'Remove trusted certificates where the',
               'subject contains FILTER') do |filter, options|
      options[:remove] << filter
    end

    add_option('-b', '--build EMAIL_ADDR',
               'Build private key and self-signed',
               'certificate for EMAIL_ADDR') do |email_address, options|
      options[:build] << Gem::Security.email_to_name(email_address)
    end

    add_option('-C', '--certificate CERT', OpenSSL::X509::Certificate,
               'Signing certificate for --sign') do |cert, options|
      options[:issuer_cert] = cert
    end

    add_option('-K', '--private-key KEY', OpenSSL::PKey::RSA,
               'Signing key for --sign') do |key, options|
      options[:issuer_key] = key
    end

    add_option('-s', '--sign CERT',
               'Signs CERT with the key from -K',
               'and the certificate from -C') do |cert_file, options|
      raise OptionParser::InvalidArgument, "#{cert_file}: does not exist" unless
        File.file? cert_file

      options[:sign] << cert_file
    end
  end

  def execute
    options[:add].each do |certificate|
      Gem::Security.trust_dir.trust_cert certificate

      say "Added '#{certificate.subject}'"
    end

    options[:remove].each do |filter|
      certificates_matching filter do |certificate, path|
        FileUtils.rm path
        say "Removed '#{certificate.subject}'"
      end
    end

    options[:list].each do |filter|
      certificates_matching filter do |certificate, _|
        # this could probably be formatted more gracefully
        say certificate.subject.to_s
      end
    end

    options[:build].each do |name|
      build name
    end

    options[:sign].each do |cert_file|
      sign cert_file
    end
  end

  def build name
    key = Gem::Security.create_key

    cert = Gem::Security.create_cert_self_signed name, key

    key_path  = Gem::Security.write key, "gem-private_key.pem"
    cert_path = Gem::Security.write cert, "gem-public_cert.pem"

    say "Certificate: #{cert_path}"
    say "Private Key: #{key_path}"
    say "Don't forget to move the key file to somewhere private!"
  end

  def certificates_matching filter
    return enum_for __method__, filter unless block_given?

    Gem::Security.trusted_certificates.select do |certificate, _|
      subject = certificate.subject.to_s
      subject.downcase.index filter
    end.sort_by do |certificate, _|
      certificate.subject.to_a.map { |name, data,| [name, data] }
    end.each do |certificate, path|
      yield certificate, path
    end
  end

  def sign cert_file
    cert = File.read cert_file
    cert = OpenSSL::X509::Certificate.new cert

    permissions = File.stat(cert_file).mode & 0777

    issuer_cert = options[:issuer_cert]
    issuer_key = options[:issuer_key]

    cert = Gem::Security.sign cert, issuer_key, issuer_cert

    Gem::Security.write cert, cert_file, permissions
  end

end

