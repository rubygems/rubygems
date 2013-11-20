# TODO: get rid of this somehow
require 'json'

##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  attr_reader :keys, :role_keys, :role_thresholds, :expires

  def initialize root_txt, root_keys = nil
    @keys, @role_keys, @role_thresholds = {}, {}, {}
    root_txt = JSON.parse(root_txt) if root_txt.is_a? String

    root_txt['signed']['keys'].each do |keyid, data|
      keys[keyid] = OpenSSL::PKey::RSA.new(data['keyval']['public'])
    end

    root_txt['signed']['roles'].each do |name, role|
      role_keys[name.to_sym]        = role['keyids'].map { |keyid| @keys[keyid] }
      role_thresholds[name.to_sym] = role['threshold']
    end

    verifier = Gem::TUF::Verifier.new(role_keys[:root], role_thresholds[:root])
    @root = verifier.verify(root_txt)

    @expires = Time.parse(@root['expires'])
  end
end
