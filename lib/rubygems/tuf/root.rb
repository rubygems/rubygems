# TODO: get rid of this somehow
require 'json'

##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  attr_reader :keys, :expires

  def initialize root_txt, root_keys = nil
    root_txt = JSON.parse(root_txt) if root_txt.is_a? String

    @keys = {}

    root_txt['signed']['keys'].each do |keyid, data|
      @keys[keyid] = OpenSSL::PKey::RSA.new(data['keyval']['public'])
    end

    # TODO: threshholds for root keys
    root_key_ids = root_txt['signed']['roles']['root']['keyids']
    root_keys = root_key_ids.map { |keyid| @keys[keyid] }

    verifier = Gem::TUF::Verifier.new(root_keys, 1)
    @root = verifier.verify(root_txt)

    @expires = Time.parse(@root['expires'])
  end
end
