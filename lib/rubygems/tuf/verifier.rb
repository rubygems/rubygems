# TODO: remove this dependency somehow
require 'json'
require 'rubygems/util/canonical_json'

##
# Verify signed JSON documents in The Update Framework (TUF) format

class Gem::TUF::Verifier
  def initialize keys, threshold = 1, now = Time.now
    @keys, @threshold = keys, threshold
  end

  def verify json, now = Time.now
    signed = json['signed']
    raise ArgumentError, "no data to sign" unless signed

    expiration = Time.parse(signed['expires'])
    raise Gem::TUF::VerificationError, "document is expired" if expiration <= now

    signatures = json['signatures']
    raise ArgumentError, "no signatures present" unless signatures

    to_verify = CanonicalJSON.dump(signed)
    verified_count = 0

    signatures.each do |signature|
      key = @keys.find { |key| key.keyid == signature['keyid'] }
      next unless key

      signature_bytes = [signature['sig']].pack("H*")
      verified = key.verify(signature_bytes, to_verify)
      verified_count += 1 if verified
    end

    if verified_count >= @threshold
      signed
    else
      raise Gem::TUF::VerificationError, "failed to meet threshhold of valid signatures (#{verified_count} of #{@threshhold})"
    end
  end
end
