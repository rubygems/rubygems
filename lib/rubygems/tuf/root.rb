# TODO: get rid of this somehow
require 'json'

##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  attr_reader :keys, :roles, :expires

  def initialize root_txt, root_keys = nil
    @keys, @roles, @role_thresholds = {}, {}, {}
    root_txt = JSON.parse(root_txt) if root_txt.is_a? String

    root_txt['signed']['keys'].each do |keyid, data|
      keys[keyid] = OpenSSL::PKey::RSA.new(data['keyval']['public'])
    end

    root_txt['signed']['roles'].each do |name, role_info|
      role_keys = {}
      role_info['keyids'].each do |keyid|
        role_keys[keyid] = @keys[keyid]
      end

      roles[name.to_sym] = Gem::TUF::Role.new(role_keys, role_info['threshold'])
    end

    verifier = Gem::TUF::Verifier.new(roles[:root].keys.values, roles[:root].threshold)
    @root = verifier.verify(root_txt)

    @expires = Time.parse(@root['expires'])
  end
end
