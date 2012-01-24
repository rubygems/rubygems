require 'rubygems/test_case'
require 'rubygems/security'
require 'rubygems/fix_openssl_warnings' if RUBY_VERSION < "1.9"

class TestGemSecurity < Gem::TestCase

  def setup
    super

    @SEC = Gem::Security
  end

  def test_class_create_cert
    name = PUBLIC_CERT.subject
    key = PRIVATE_KEY

    cert = @SEC.create_cert name, key, 60

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

    assert_equal '', cert.issuer.to_s
    assert_equal name.to_s, cert.subject.to_s
  end

  def test_class_create_cert_self_signed
    subject = PUBLIC_CERT.subject

    cert = @SEC.create_cert_self_signed subject, PRIVATE_KEY, 60

    assert_equal '/CN=nobody/DC=example', cert.issuer.to_s
  end

  def test_class_create_key
    key = @SEC.create_key 256

    assert_kind_of OpenSSL::PKey::RSA, key
  end

  def test_class_email_to_name
    assert_equal '/CN=nobody/DC=example',
                 @SEC.email_to_name('nobody@example').to_s

    assert_equal '/CN=nobody/DC=example/DC=com',
                 @SEC.email_to_name('nobody@example.com').to_s

    assert_equal '/CN=no.body/DC=example',
                 @SEC.email_to_name('no.body@example').to_s

    assert_equal '/CN=no_body/DC=example',
                 @SEC.email_to_name('no+body@example').to_s
  end

  def test_class_reset
    trust_dir = @SEC.trust_dir

    @SEC.reset

    refute_equal trust_dir, @SEC.trust_dir
  end

  def test_class_sign
    issuer = PUBLIC_CERT.subject
    signee = OpenSSL::X509::Name.parse "/CN=signee/DC=example"

    key  = PRIVATE_KEY
    cert = OpenSSL::X509::Certificate.new
    cert.subject = signee

    cert.subject    = signee
    cert.public_key = key.public_key

    signed = @SEC.sign cert, key, PUBLIC_CERT

    assert_equal    key.public_key.to_pem, signed.public_key.to_pem
    assert_equal    signee.to_s,           signed.subject.to_s
    assert_equal    issuer.to_s,           signed.issuer.to_s

    assert_in_delta Time.now,              signed.not_before, 10
    assert_in_delta Time.now + Gem::Security::ONE_YEAR,
                    signed.not_after, 10

    assert_equal 3, signed.extensions.length

    constraints = signed.extensions.find { |ext| ext.oid == 'basicConstraints' }
    assert_equal 'CA:FALSE', constraints.value

    key_usage = signed.extensions.find { |ext| ext.oid == 'keyUsage' }
    assert_equal 'Digital Signature, Key Encipherment, Data Encipherment',
                 key_usage.value

    key_ident =
      signed.extensions.find { |ext| ext.oid == 'subjectKeyIdentifier' }
    assert_equal 59, key_ident.value.length
    assert_equal 'B0:EB:9C:A5:E5:8E:7D:94:BB:4B:3B:D6:80:CB:A5:AD:5D:12:88:90',
                 key_ident.value

    assert signed.verify key
  end

  def test_class_trust_dir
    trust_dir = @SEC.trust_dir

    expected = File.join Gem.user_home, '.gem/trust'

    assert_equal expected, trust_dir.dir
  end

end

