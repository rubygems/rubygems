# frozen_string_literal: true
require 'openssl'
require 'time'

class CertificateBuilder

  attr_reader :today

  def initialize key_size = 2048
    today           = Time.now.utc
    @today          = Time.utc today.year, today.month, today.day
    @end_of_time    = Time.utc 9999, 12, 31, 23, 59, 59
    @end_of_time_32 = Time.utc 2038, 01, 19, 03, 14, 07

    @serial = 0
  end

  def create_certificates(key, subject, issuer_key = key, issuer = subject,
                          not_before: @today, not_after: :end_of_time)
    certificates = []

    not_before, not_before_32 = validity_for not_before
    not_after,  not_after_32  = validity_for not_after

    certificates <<
      create_certificate(key, subject, issuer_key, issuer,
                         not_before, not_after)
    certificates <<
      create_certificate(key, subject, issuer_key, issuer,
                         not_before_32, not_after_32)

    certificates
  end

  def create_certificate key, subject, issuer_key, issuer, not_before, not_after
    puts "creating cert - subject: #{subject}, issuer: #{issuer}"
    cert = OpenSSL::X509::Certificate.new
    cert.version    = 2
    cert.serial     = 0

    cert.not_before = not_before
    cert.not_after  = not_after

    cert.serial = next_serial

    cert.public_key = key.public_key

    cert.subject =
      OpenSSL::X509::Name.new [%W[CN #{subject}], %w[DC example]]
    cert.issuer  =
      OpenSSL::X509::Name.new [%W[CN #{issuer}],  %w[DC example]]

    ef = OpenSSL::X509::ExtensionFactory.new nil, cert

    cert.extensions = [
      ef.create_extension('subjectAltName', "email:#{subject}@example")
    ]

    cert.sign issuer_key, OpenSSL::Digest::SHA1.new

    cert
  end

  def create_key
    puts "creating key"
    OpenSSL::PKey::RSA.new 2048
  end

  def create_keys names
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

  def validity_for time
    if time == :end_of_time then
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

certs = {
  alternate:
    cb.create_certificates(keys[:alternate], 'alternate'),
  child:
    cb.create_certificates(keys[:child], 'child',
                           keys[:private], 'nobody'),
  expired:
    cb.create_certificates(keys[:private], 'nobody',
                           not_before: Time.at(0),
                           not_after: Time.at(0)),
  future:
    cb.create_certificates(keys[:private], 'nobody',
                           not_before: :end_of_time,
                           not_after: :end_of_time),
  grandchild:
    cb.create_certificates(keys[:grandchild], 'grandchild',
                           keys[:child], 'child'),
  invalid_issuer:
    cb.create_certificates(keys[:invalid], 'invalid',
                           keys[:invalid], 'nobody'),
  invalid_signer:
    cb.create_certificates(keys[:invalid], 'invalid',
                           keys[:private], 'invalid'),
  invalidchild:
    cb.create_certificates(keys[:invalidchild], 'invalidchild',
                           keys[:invalid], 'child'),
  public:
    cb.create_certificates(keys[:private], 'nobody'),
  wrong_key:
    cb.create_certificates(keys[:alternate], 'nobody'),
}

base_dir = 'test/rubygems'

keys.each do |name, key|
  dest = File.join base_dir, "#{name}_key.pem"
  File.write dest, key.to_pem
end

certs.each do |name, (cert, cert_32)|
  dest = File.join base_dir, "#{name}_cert.pem"
  File.write dest, cert.to_pem

  dest = File.join base_dir, "#{name}_cert_32.pem"
  File.write dest, cert_32.to_pem
end

