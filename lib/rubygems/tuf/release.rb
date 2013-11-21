require 'json'

class Gem::TUF::Release
  attr_reader :targets

  def initialize root, release_txt
    parsed = JSON.parse release_txt
    @release = root.verify(:release, parsed)
    @targets = @release["meta"]["targets.txt"]
  end

  def should_update_root? current_root_txt
    @release["meta"]["root.txt"]["hashes"].each do |type, expected_digest|
      current_digest = case type
                       when "sha512"
                         Digest::SHA512.hexdigest(current_root_txt)
                       else
                         raise UnsupportedDigest
                       end
      return true unless current_digest == expected_digest
    end
    false
  end
end
