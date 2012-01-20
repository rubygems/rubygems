require 'rubygems/command'
require 'rubygems/security'

class Gem::Commands::CertCommand < Gem::Command

  def initialize
    super 'cert', 'Manage RubyGems certificates and signing settings'

    add_option('-a', '--add CERT',
               'Add a trusted certificate.') do |value, options|
      cert = OpenSSL::X509::Certificate.new File.read value

      Gem::Security.trust_dir.trust_cert cert

      say "Added '#{cert.subject}'"
    end

    add_option('-l', '--list',
               'List trusted certificates.') do |value, options|
      Gem::Security.trusted_certificates do |certificate, _|
        # this could probably be formatted more gracefully
        say certificate.subject.to_s
      end
    end

    add_option('-r', '--remove STRING',
               'Remove trusted certificates containing',
               'STRING.') do |value, options|
      Gem::Security.trusted_certificates.each do |certificate, path|
        if certificate.subject.to_s.downcase.index value then
          FileUtils.rm path
          say "Removed '#{certificate.subject}'"
        end
      end
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

    add_option('-C', '--certificate CERT',
               'Certificate for --sign command.') do |value, options|
      cert = OpenSSL::X509::Certificate.new File.read value

      options[:issuer_cert] = cert
    end

    add_option('-K', '--private-key KEY',
               'Private key for --sign command.') do |value, options|
      key = OpenSSL::PKey::RSA.new File.read value

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
  end

end

