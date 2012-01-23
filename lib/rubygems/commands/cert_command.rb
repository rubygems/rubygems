require 'rubygems/command'
require 'rubygems/security'

class Gem::Commands::CertCommand < Gem::Command

  def initialize
    super 'cert', 'Manage RubyGems certificates and signing settings',
          :add => [], :remove => []

    OptionParser.accept OpenSSL::X509::Certificate do |certificate|
      OpenSSL::X509::Certificate.new File.read certificate
    end

    OptionParser.accept OpenSSL::PKey::RSA do |key|
      OpenSSL::PKey::RSA.new File.read key
    end

    add_option('-a', '--add CERT', OpenSSL::X509::Certificate,
               'Add a trusted certificate.') do |cert, options|
      options[:add] << cert
    end

    add_option('-l', '--list',
               'List trusted certificates.') do |value, options|
      Gem::Security.trusted_certificates do |certificate, _|
        # this could probably be formatted more gracefully
        say certificate.subject.to_s
      end
    end

    add_option('-r', '--remove STRING',
               'Remove trusted certificates where the',
               'subject contains STRING') do |string, options|
      options[:remove] << string
    end

    add_option('-b', '--build EMAIL_ADDR',
               'Build private key and self-signed',
               'certificate for EMAIL_ADDR.') do |email_address, options|
      name = Gem::Security.email_to_name email_address

      key = Gem::Security.create_key

      cert = Gem::Security.create_cert_self_signed name, key

      key_path  = Gem::Security.write key, "gem-private_key.pem"
      cert_path = Gem::Security.write cert, "gem-public_cert.pem"

      say "Certificate: #{cert_path}"
      say "Private Key: #{key_path}"
      say "Don't forget to move the key file to somewhere private..."
    end

    add_option('-C', '--certificate CERT', OpenSSL::X509::Certificate,
               'Certificate for --sign command.') do |cert, options|
      options[:issuer_cert] = cert
    end

    add_option('-K', '--private-key KEY', OpenSSL::PKey::RSA,
               'Private key for --sign command.') do |key, options|
      options[:issuer_key] = key
    end

    add_option('-s', '--sign NEWCERT',
               'Sign a certificate with my key and',
               'certificate.') do |cert_file, options|
      cert = OpenSSL::X509::Certificate.new File.read cert_file

      permissions = File.stat(cert_file).mode & 0777

      my_cert = options[:issuer_cert]
      my_key = options[:issuer_key]

      cert = Gem::Security.sign cert, my_key, my_cert

      Gem::Security.write cert, cert_file, permissions
    end
  end

  def execute
    options[:add].each do |certificate|
      Gem::Security.trust_dir.trust_cert certificate

      say "Added '#{certificate.subject}'"
    end

    options[:remove].each do |string|
      Gem::Security.trusted_certificates.select do |certificate, _|
        subject = certificate.subject.to_s
        subject.downcase.index string
      end.each do |certificate, path|
        FileUtils.rm path
        say "Removed '#{certificate.subject}'"
      end
    end
  end

end

