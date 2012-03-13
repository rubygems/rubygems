class Gem::Package::DigestIO

  attr_reader :digest

  def self.wrap io, digest
    digest_io = new io, digest

    yield digest_io

    return digest
  end

  def initialize io, digest
    @io = io
    @digest = digest
  end

  def write data
    @digest << data
    @io.write data
  end

end

