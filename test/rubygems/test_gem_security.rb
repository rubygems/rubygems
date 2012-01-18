require 'rubygems/test_case'
require 'rubygems/security'
require 'rubygems/fix_openssl_warnings' if RUBY_VERSION < "1.9"

class TestGemSecurity < Gem::TestCase

  def test_class_build_cert
    name = PUBLIC_CERT.subject
    key = PRIVATE_KEY
    opt = { :cert_age => 60 }

    cert = Gem::Security.build_cert name, key, opt

    assert_kind_of OpenSSL::X509::Certificate, cert

    assert_equal    3,                     cert.version
    assert_equal    1,                     cert.serial
    assert_equal    key.public_key.to_pem, cert.public_key.to_pem
    assert_in_delta Time.now,              cert.not_before, 10
    assert_in_delta Time.now + 60,         cert.not_after, 10
    assert_equal    name.to_s,             cert.subject.to_s

    assert_equal 3, cert.extensions.length

    constraints = cert.extensions.find { |ext| ext.oid == 'basicConstraints' }
    assert_equal 'CA:FALSE', constraints.value

    key_usage = cert.extensions.find { |ext| ext.oid == 'keyUsage' }
    assert_equal 'Digital Signature, Key Encipherment, Data Encipherment',
                 key_usage.value

    key_ident = cert.extensions.find { |ext| ext.oid == 'subjectKeyIdentifier' }
    assert_equal 59, key_ident.value.length
    assert_equal 'B0:EB:9C:A5:E5:8E:7D:94:BB:4B:3B:D6:80:CB:A5:AD:5D:12:88:90',
                 key_ident.value

    assert_equal name.to_s, cert.issuer.to_s
    assert_equal name.to_s, cert.subject.to_s
  end

  def test_class_build_self_signed_cert
    email = 'nobody@example'

    opt = {
      :cert_age  => 60,
      :key_size  => 512,
      :save_cert => false,
      :save_key  => false,
    }

    result = Gem::Security.build_self_signed_cert email, opt

    key = result[:key]

    assert_kind_of OpenSSL::PKey::RSA, key

    cert = result[:cert]

    assert_equal '/CN=nobody/DC=example', cert.issuer.to_s
  end

  def test_class_sign_cert
    name = PUBLIC_CERT.subject
    key  = PRIVATE_KEY
    cert = OpenSSL::X509::Certificate.new

    cert.subject    = name
    cert.public_key = key.public_key

    signed = Gem::Security.sign_cert cert, key, cert

    assert cert.verify key
    assert_equal name.to_s, signed.subject.to_s
  end

  def test_trusted_cert_path
    path = Gem::Security.trusted_cert_path PUBLIC_CERT

    digest = OpenSSL::Digest::SHA1.hexdigest PUBLIC_CERT.subject.to_s

    expected = File.join @userhome, ".gem/trust/cert-#{digest}.pem"

    assert_equal expected, path
  end

  def test_trusted_cert_path_digest
    path = Gem::Security.trusted_cert_path PUBLIC_CERT

    digest = Gem::Security::DIGEST_ALGORITHM.hexdigest PUBLIC_CERT.subject.to_s

    expected = File.join @userhome, ".gem/trust/cert-#{digest}.pem"

    assert_equal expected, path
  end

  def test_trusted_cert_path_trust_dir
    trust_dir = File.join @userhome, 'my_trust'

    path = Gem::Security.trusted_cert_path PUBLIC_CERT, :trust_dir => trust_dir

    digest = OpenSSL::Digest::SHA1.hexdigest PUBLIC_CERT.subject.to_s

    expected = File.join trust_dir, "cert-#{digest}.pem"

    assert_equal expected, path
  end

  def test_class_email_to_name
    assert_equal '/CN=nobody/DC=example',
                 Gem::Security.email_to_name('nobody@example').to_s

    assert_equal '/CN=nobody/DC=example/DC=com',
                 Gem::Security.email_to_name('nobody@example.com').to_s

    assert_equal '/CN=no.body/DC=example',
                 Gem::Security.email_to_name('no.body@example').to_s

    assert_equal '/CN=no_body/DC=example',
                 Gem::Security.email_to_name('no+body@example').to_s
  end

end if defined?(OpenSSL)

