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
      keys[keyid] = OpenSSL::PKey::RSA.new(data['keyval']['public'])
    end

    root_txt['signed']['roles'].each do |name, role_info|
      role_key_hash = role_keys[name.to_sym] = {}
      role_info['keyids'].each do |keyid|
        role_key_hash[keyid] = keys[keyid]
      end

      role_thresholds[name.to_sym] = role_info['threshold']
    end

    @root    = verify(:root, root_txt)
    @expires = Time.parse(@root['expires'])
  end

  def verify(role_name, document, now = Time.now)
    keys      = role_keys[role_name.to_sym]
    threshold = role_thresholds[role_name.to_sym]
    verifier  = Gem::TUF::Verifier.new(keys, threshold)

    verifier.verify(document)
  end
end
