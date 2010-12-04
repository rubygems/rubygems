require File.expand_path('../gemutilities', __FILE__)
require 'rubygems/security'

class TestGemSecurity < RubyGemTestCase

  def test_class_build_cert
    name = OpenSSL::X509::Name.parse "CN=nobody/DC=example"
    key = OpenSSL::PKey::RSA.new 512
    opt = { :cert_age => 60 }

    cert = Gem::Security.build_cert name, key, opt

    assert_kind_of OpenSSL::X509::Certificate, cert


    assert_equal    2,                     cert.version
    assert_equal    0,                     cert.serial
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

    assert_equal name.to_s, cert.issuer.to_s
    assert_equal name.to_s, cert.subject.to_s
  end

end

