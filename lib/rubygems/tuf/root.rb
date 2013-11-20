##
# Determines if TUF targets are authentic

class Gem::TUF::Root
  def initialize root_txt, root_keys
    # TODO: threshholds for root keys
    verifier = Gem::TUF::Verifier.new(root_keys, 1)
    @root = verifier.verify(root_txt)
  end
end
