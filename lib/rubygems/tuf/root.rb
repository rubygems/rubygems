# TODO: get rid of this somehow
require 'json'

##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  attr_reader :keys, :role_keys, :role_thresholds, :expires

  def initialize root_txt
    @keys, @role_keys, @role_thresholds = {}, {}, {}
    root_txt = JSON.parse(root_txt) if root_txt.is_a? String

    root_txt['signed']['keys'].each do |keyid, data|
      rsa_key     = OpenSSL::PKey::RSA.new data['keyval']['public']
      public_key  = Gem::TUF::PublicKey.new rsa_key

      unless public_key.keyid == keyid
        raise "internal inconsistency: keyid #{public_key.keyid} does not match expected #{keyid}"
      end

      keys[keyid] = public_key
    end

    root_txt['signed']['roles'].each do |name, role_info|
      role_key_array = role_keys[name.to_sym] = []
      role_info['keyids'].each do |keyid|
        role_key = keys[keyid]
        raise "internal inconsistency: couldn't find public key #{keyid} for role #{name}" unless role_key
        role_key_array << role_key
      end

      role_thresholds[name.to_sym] = role_info['threshold']
    end

    @root    = verify :root, root_txt
    @expires = Time.parse @root['expires']
  end

  def verify role_name, document, now = Time.now
    keys      = role_keys[role_name.to_sym]
    threshold = role_thresholds[role_name.to_sym]
    verifier  = Gem::TUF::Verifier.new keys, threshold

    verifier.verify document
  end
end
