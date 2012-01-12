# coding: UTF-8

require 'rubygems/test_case'

class TestRubygemsSecurityPolicy < Gem::TestCase

  def setup
    super

    @spec = quick_gem 'a' do |s|
      s.description = 'π'
      s.files = %w[lib/code.rb]
    end
  end

  def test_verify_signatures
    Gem::Security.add_trusted_cert PUBLIC_CERT

    digest = Gem::Security::OPT[:dgst_algo]

    @spec.cert_chain = [PUBLIC_CERT.to_s]

    metadata_gz = Gem.gzip @spec.to_yaml

    package = Gem::Package.new 'nonexistent.gem'

    metadata_gz_digest = package.digest StringIO.new metadata_gz

    digests = {}
    digests['metadata.gz'] = metadata_gz_digest

    signatures = {}
    signatures['metadata.gz'] =
      PRIVATE_KEY.sign digest.new, metadata_gz_digest.digest

    Gem::Security::HighSecurity.verify_signatures @spec, digests, signatures
  end

  def test_verify_signatures_missing
    Gem::Security.add_trusted_cert PUBLIC_CERT

    digest = Gem::Security::OPT[:dgst_algo]

    @spec.cert_chain = [PUBLIC_CERT.to_s]

    metadata_gz = Gem.gzip @spec.to_yaml

    package = Gem::Package.new 'nonexistent.gem'

    metadata_gz_digest = package.digest StringIO.new metadata_gz

    digests = {}
    digests['metadata.gz'] = metadata_gz_digest
    digests['data.tar.gz'] = package.digest StringIO.new 'hello' # fake

    signatures = {}
    signatures['metadata.gz'] =
      PRIVATE_KEY.sign digest.new, metadata_gz_digest.digest

    e = assert_raises Gem::Security::Exception do
      Gem::Security::HighSecurity.verify_signatures @spec, digests, signatures
    end

    assert_equal 'missing signature for data.tar.gz', e.message
  end

end

