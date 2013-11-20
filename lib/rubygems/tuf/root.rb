# TODO: get rid of this somehow
require 'json'

##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  def initialize root_txt, root_keys = nil
    root_txt = JSON.parse(root_txt) if root_txt.is_a? String

    # Extract root keys if not otherwise specified
    root_keys ||= root_txt['signed']['keys'].map do |_, data|
      OpenSSL::PKey::RSA.new(data['keyval']['public'])
    end

    # TODO: threshholds for root keys
    verifier = Gem::TUF::Verifier.new(root_keys, 1)
    @root = verifier.verify(root_txt)
  end
end
