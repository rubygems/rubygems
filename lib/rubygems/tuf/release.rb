require 'json'

class Gem::TUF::Release
  attr_reader :targets

  def initialize root, release_txt
    parsed = JSON.parse release_txt
    @release = root.verify(:release, parsed)
    @targets = @release["meta"]["targets.txt"]
  end
end
