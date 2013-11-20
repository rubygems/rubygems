# TODO: remove this dependency somehow
require 'json'
require 'rubygems/util/canonical_json'

##
# Produce signed JSON documents in The Update Framework (TUF) format

class Gem::TUF::Verifier
  def initialize keys, threshold = 1
    @keys, @threshold = keys, threshold
  end

  def verify json
    signed = json['signed']
    raise ArgumentError, "no data to sign" unless signed

    signatures = json['signatures']
    raise ArgumentError, "no signatures present" unless signatures

    to_verify = CanonicalJSON.dump(signed)
    verified_count = 0

    signatures.each do |signature|
      key = @keys[signature['keyid']]
      next unless key

      signature_bytes = [signature['sig']].pack("H*")
      verified = key.verify(Gem::TUF::DIGEST_ALGORITHM.new, signature_bytes, to_verify)
      verified_count += 1 if verified
    end

    if verified_count >= @threshold
      signed
    else
      raise "failed to meet threshold of valid signatures (#{verified_count} of #{@threshold})"
    end
  end
end
