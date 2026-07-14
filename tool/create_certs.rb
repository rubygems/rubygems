# frozen_string_literal: true

require "openssl"

class CertificateBuilder
  attr_reader :start

  BASE_DIR = "test/rubygems"

  def initialize(prefix: "")
    @prefix         = prefix
    @start          = Time.utc 2012, 1, 1, 0, 0, 0
    @end_of_time    = Time.utc 9999, 12, 31, 23, 59, 59
    @end_of_time_32 = Time.utc 2038, 1, 19, 3, 14, 7

    @serial = 0
  end

  def execute
    keys, certs = create_keys_and_certificates
    write_keys_and_certificates(keys, certs)
  end

  def create_keys_and_certificates
    keys = create_keys [
      :alternate,
      :child,
      :grandchild,
      :invalid,
      :invalidchild,
      :private,
    ]

    certs = {}
    certs[:public] =
      create_certificates(keys[:private], "nobody",
                           is_ca: true)
    certs[:child] =
      create_certificates(keys[:child], "child",
                           keys[:private], certs[:public],
                           is_ca: true)
    certs[:alternate] =
      create_certificates(keys[:alternate], "alternate")
    certs[:expired] =
      create_certificates(keys[:private], "nobody",
                           not_before: Time.at(0),
                           not_after: Time.at(0))
    certs[:future] =
      create_certificates(keys[:private], "nobody",
                           not_before: :end_of_time,
                           not_after: :end_of_time)
    certs[:invalid_issuer] =
      create_certificates(keys[:invalid], "invalid",
                           keys[:invalid], certs[:public],
                           is_ca: true)
    certs[:grandchild] =
      create_certificates(keys[:grandchild], "grandchild",
                           keys[:child], certs[:child])
    certs[:invalid_signer] =
      create_certificates(keys[:invalid], "invalid",
                           keys[:private], certs[:invalid])
    certs[:invalidchild] =
      create_certificates(keys[:invalidchild], "invalidchild",
                           keys[:invalid], certs[:child])
    certs[:wrong_key] =
      create_certificates(keys[:alternate], "nobody")

    [keys, certs]
  end

  def create_certificates(key, subject, issuer_key = key, issuer_cert = nil,
    not_before: @start, not_after: :end_of_time, is_ca: false)
    certificates = []

    not_before, not_before_32 = validity_for not_before
    not_after,  not_after_32  = validity_for not_after
    issuer_cert, issuer_cert_32 = issuer_cert

    certificates <<
      create_certificate(key, subject, issuer_key, issuer_cert,
                         not_before, not_after, is_ca)

    # When not_before and not_after are the same between the regular and 32-bit
    # certificates, don't create 32-bit certificate. Because it is redundant.
    if not_before == not_before_32 && not_after == not_after_32
      certificates << nil
    else
      certificates <<
        create_certificate(key, subject, issuer_key, issuer_cert_32,
                           not_before_32, not_after_32, is_ca)
    end

    certificates
  end

  def create_certificate(key, subject, issuer_key, issuer_cert,
    not_before, not_after, is_ca)
    cert = OpenSSL::X509::Certificate.new
    issuer_cert ||= cert # if not specified, create self signing cert

    cert.version    = 2
    cert.serial     = 0

    cert.not_before = not_before
    cert.not_after  = not_after

    cert.serial = next_serial

    cert.public_key = OpenSSL::PKey.read(key.public_to_pem)

    cert.subject = OpenSSL::X509::Name.new [%W[CN #{subject}], %w[DC example]]
    cert.issuer  = issuer_cert.subject

    ef = OpenSSL::X509::ExtensionFactory.new issuer_cert, cert

    cert.extensions = [
      ef.create_extension("subjectAltName", "email:#{subject}@example"),
      ef.create_extension("subjectKeyIdentifier", "hash"),
    ]

    if cert != issuer_cert # not self-signed cert
      cert.add_extension ef.create_extension("authorityKeyIdentifier", "keyid:always")
    end

    if is_ca
      cert.add_extension ef.create_extension("basicConstraints", "CA:TRUE", true)
      cert.add_extension ef.create_extension("keyUsage", "keyCertSign", true)
    end

    cert.sign issuer_key, digest_name

    puts "created cert - subject: #{cert.subject}, issuer: #{cert.issuer}"
    cert
  end

  def create_keys(names)
    keys = {}

    names.each do |name|
      keys[name] = create_key
    end

    keys
  end

  def next_serial
    serial = @serial
    @serial += 1
    serial
  end

  def validity_for(time)
    if time == :end_of_time
      validity    = @end_of_time
      validity_32 = @end_of_time_32
    else
      validity = validity_32 = time
    end

    [validity, validity_32]
  end

  def write_keys_and_certificates(keys, certs)
    cipher = "aes-256-cbc"
    passphrase = "Foo bar"

    keys.each do |name, key|
      dest = File.join BASE_DIR, "#{@prefix}#{name}_key.pem"
      File.write dest, key.private_to_pem

      next unless name == :private

      # Write the public key PEM from the private key
      dest = File.join BASE_DIR, "#{@prefix}public_key.pem"
      File.write dest, key.public_to_pem

      # Create an encrypted private key protected by a passphrase
      # it has to be the same as is in test/rubygems/helper.rb in PRIVATE_KEY_PASSPHRASE
      dest = File.join BASE_DIR, "#{@prefix}encrypted_#{name}_key.pem"
      File.write dest, key.private_to_pem(cipher, passphrase)
    end

    certs.each do |name, (cert, cert_32)|
      dest = File.join BASE_DIR, "#{@prefix}#{name}_cert.pem"
      File.write dest, cert.to_pem

      next unless cert_32

      dest = File.join BASE_DIR, "#{@prefix}#{name}_cert_32.pem"
      File.write dest, cert_32.to_pem
    end
  end
end

class RSACertificateBuilder < CertificateBuilder
  def initialize(key_size: 2048)
    super(prefix: "")
    @key_size = key_size
  end

  def create_key
    puts "creating RSA key"
    OpenSSL::PKey::RSA.new @key_size
  end

  def digest_name
    "SHA256"
  end
end

class MLDSA65CertificateBuilder < CertificateBuilder
  def initialize
    super(prefix: "mldsa65_")
  end

  # Only create the private key and public cert needed for current tests.
  def create_keys_and_certificates
    keys = create_keys [
      :private,
    ]

    certs = {}
    certs[:public] =
      create_certificates(keys[:private], "nobody",
                           is_ca: true)

    [keys, certs]
  end

  def create_key
    puts "creating ML-DSA-65 key"
    OpenSSL::PKey.generate_key("ML-DSA-65")
  end

  # ML-DSA keys do not support explicit digest algorithms.
  def digest_name
    nil
  end
end

# Create RSA and ML-DSA-65 certificates
[
  RSACertificateBuilder.new,
  MLDSA65CertificateBuilder.new,
].each(&:execute)
