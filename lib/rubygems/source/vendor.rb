##
# This represents a vendored source that is similar to an installed gem.

class Gem::Source::Vendor < Gem::Source::Installed

  ##
  # Creates a new Vendor source for a gem that was unpacked at +path+.

  def initialize path
    @uri = path
  end

  def <=> other
    case other
    when Gem::Source::Lock
      -1
    when Gem::Source::Vendor
      0
    when Gem::Source
      1
    else
      nil
    end
  end

end

