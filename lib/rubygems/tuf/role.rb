##
# Encapsulates the configuration for a TUF role

class Gem::TUF::Role
  attr_reader :keys, :threshold

  def initialize keys, threshold
    @keys, @threshold = keys, threshold
  end
end
