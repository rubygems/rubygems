# frozen_string_literal: true

require "openssl"

class CertificateBuilder
  attr_reader :start

  def initialize(key_size = 2048)
    @start          = Time.utc 2012, 1, 1, 0, 0, 0
    @end_of_time    = Time.utc 9999, 12, 31, 23, 59, 59
    @end_of_time_32 = Time.utc 2038, 1, 19, 3, 14, 7

    @key_size = key_size
    @serial = 0
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
    certificates <<
      create_certificate(key, subject, issuer_key, issuer_cert_32,
                         not_before_32, not_after_32, is_ca)

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

    cert.public_key = key.public_key

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

    cert.sign issuer_key, "SHA256"

    puts "created cert - subject: #{cert.subject}, issuer: #{cert.issuer}"
    cert
  end

  def create_key
    puts "creating key"
    OpenSSL::PKey::RSA.new @key_size
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
end

cb = CertificateBuilder.new

keys = cb.create_keys [
  :alternate,
  :child,
  :grandchild,
  :invalid,
  :invalidchild,
  :private,
]

keys[:public] = keys[:private].public_key

certs = {}
certs[:public] =
  cb.create_certificates(keys[:private], "nobody",
                         is_ca: true)
certs[:child] =
  cb.create_certificates(keys[:child], "child",
                         keys[:private], certs[:public],
                         is_ca: true)
certs[:alternate] =
  cb.create_certificates(keys[:alternate], "alternate")
certs[:expired] =
  cb.create_certificates(keys[:private], "nobody",
                         not_before: Time.at(0),
                         not_after: Time.at(0))
certs[:future] =
  cb.create_certificates(keys[:private], "nobody",
                         not_before: :end_of_time,
                         not_after: :end_of_time)
certs[:invalid_issuer] =
  cb.create_certificates(keys[:invalid], "invalid",
                         keys[:invalid], certs[:public],
                         is_ca: true)
certs[:grandchild] =
  cb.create_certificates(keys[:grandchild], "grandchild",
                         keys[:child], certs[:child])
certs[:invalid_signer] =
  cb.create_certificates(keys[:invalid], "invalid",
                         keys[:private], certs[:invalid])
certs[:invalidchild] =
  cb.create_certificates(keys[:invalidchild], "invalidchild",
                         keys[:invalid], certs[:child])
certs[:wrong_key] =
  cb.create_certificates(keys[:alternate], "nobody")

base_dir = "test/rubygems"

keys.each do |name, key|
  dest = File.join base_dir, "#{name}_key.pem"
  File.write dest, key.to_pem
end

# Create an encrypted private key protected by a passhrase from the new keys[:private]
# it has to be the same as is in # test/rubygems/helper.rb in PRIVATE_KEY_PASSPHRASE
dest = File.join base_dir, "encrypted_private_key.pem"
File.write dest, keys[:private].to_pem(OpenSSL::Cipher.new("aes-256-cbc"), "Foo bar")

certs.each do |name, (cert, cert_32)|
  dest = File.join base_dir, "#{name}_cert.pem"
  File.write dest, cert.to_pem

  dest = File.join base_dir, "#{name}_cert_32.pem"
  File.write dest, cert_32.to_pem
end
