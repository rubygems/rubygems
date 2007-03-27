module Gem
  module Commands
    
    class CertCommand < Command
      include CommandAids
    
      def initialize
        super(
          'cert',
          'Adjust RubyGems certificate settings',
          {
          })

        add_option('-a', '--add CERT', 'Add a trusted certificate.') do |value, options|
          cert = OpenSSL::X509::Certificate.new(File.read(value))
          Gem::Security.add_trusted_cert(cert)
          puts "Added #{cert.subject.to_s}"
        end

        add_option('-l', '--list', 'List trusted certificates.') do |value, options|
          glob_str = File::join(Gem::Security::OPT[:trust_dir], '*.pem')
          Dir::glob(glob_str) do |path|
            cert = OpenSSL::X509::Certificate.new(File.read(path))
            # this could proably be formatted more gracefully
            puts cert.subject.to_s
          end
        end

        add_option('-r', '--remove STRING',
                   'Remove trusted certificates containing',
                   'STRING.') do |value, options|
          trust_dir = Gem::Security::OPT[:trust_dir]
          glob_str = File::join(trust_dir, '*.pem')

          Dir::glob(glob_str) do |path|
            cert = OpenSSL::X509::Certificate.new(File.read(path))
            if cert.subject.to_s.downcase.index(value)
              puts "Removing '#{cert.subject.to_s}'"
              File.unlink(path)
            end
          end
        end

        add_option('-b', '--build EMAIL_ADDR',
                   'Build private key and self-signed',
                   'certificate for EMAIL_ADDR.') do |value, options|
          vals = Gem::Security::build_self_signed_cert(value)
          File::chmod(0600, vals[:key_path])
          puts "Public Cert: #{vals[:cert_path]}",
               "Private Key: #{vals[:key_path]}",
               "Don't forget to move the key file to somewhere private..."
        end

        add_option('-C', '--certificate CERT',
                   'Certificate for --sign command.') do |value, options|
          cert = OpenSSL::X509::Certificate.new(File.read(value))
          Gem::Security::OPT[:issuer_cert] = cert
        end

        add_option('-K', '--private-key KEY',
                   'Private key for --sign command.') do |value, options|
          key = OpenSSL::PKey::RSA.new(File.read(value))
          Gem::Security::OPT[:issuer_key] = key
        end


        add_option('-s', '--sign NEWCERT', 
                   'Sign a certificate with my key and',
                   'certificate.') do |value, options|
          cert = OpenSSL::X509::Certificate.new(File.read(value))
          my_cert = Gem::Security::OPT[:issuer_cert]
          my_key = Gem::Security::OPT[:issuer_key]
          cert = Gem::Security.sign_cert(cert, my_key, my_cert)
          File::open(value, 'wb') { |file| file.write(cert.to_pem) }
        end

      end

      def execute
      end
    end
  end
end