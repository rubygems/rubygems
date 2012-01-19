require 'rubygems/test_case'

class TestGemSecuritySigner < Gem::TestCase

  ALTERNATE_KEY = load_key 'alternate'

  CHILD_CERT   = load_cert 'child'
  EXPIRED_CERT = load_cert 'expired'

  def setup
    super

    @cert_file =
      if 32 == (Time.at(2**32) rescue 32) then
        File.expand_path 'test/rubygems/public_cert_32.pem', @current_dir
      else
        File.expand_path 'test/rubygems/public_cert.pem', @current_dir
      end
  end

  def test_initialize_cert_chain_mixed
    signer = Gem::Security::Signer.new nil, [@cert_file, CHILD_CERT]

    assert_equal [PUBLIC_CERT, CHILD_CERT].inspect, signer.cert_chain.inspect
  end

  def test_initialize_cert_chain_invalid
    assert_raises OpenSSL::X509::CertificateError do
      Gem::Security::Signer.new nil, ['garbage']
    end
  end

  def test_initialize_cert_chain_path
    signer = Gem::Security::Signer.new nil, [@cert_file]

    assert_equal [PUBLIC_CERT].inspect, signer.cert_chain.inspect
  end

  def test_initialize_key_path
    key_file = File.expand_path 'test/rubygems/private_key.pem', @current_dir

    signer = Gem::Security::Signer.new key_file, nil

    assert_equal PRIVATE_KEY.to_s, signer.key.to_s
  end

  def test_sign
    signer = Gem::Security::Signer.new PRIVATE_KEY, [PUBLIC_CERT]

    signature = signer.sign 'hello'

    expected = <<-EXPECTED
oZXzQRdq0mJpAghICQvjvlB7ZyZtE4diL5jce0Fa20PkLjOvDgpuZCs6Ppu5
LtG89EQMMBHsAyc8NMCd4oWm6Q==
    EXPECTED

    assert_equal expected, [signature].pack('m')
  end

  def test_sign_expired
    signer = Gem::Security::Signer.new PRIVATE_KEY, [EXPIRED_CERT]

    assert_raises Gem::Security::Exception do
      signer.sign 'hello'
    end
  end

  def test_sign_wrong_key
    signer = Gem::Security::Signer.new ALTERNATE_KEY, [PUBLIC_CERT]

    assert_raises Gem::Security::Exception do
      signer.sign 'hello'
    end
  end

  def test_sign_no_key
    signer = Gem::Security::Signer.new nil, []

    assert_nil signer.sign 'stuff'
  end

end

