require 'zlib'
require 'rubygems/indexer'

# Mixin that provides a +compress+ method for compressing files on disk.
module Gem::Indexer::Compressor

  # Compress the given file.
  def compress(filename, ext="rz")
    File.open filename + ".#{ext}", "wb" do |file|
      file.write zip(File.read(filename))
    end
  end

  # Return a compressed version of the given string.
  def zip(string)
    Zlib::Deflate.deflate(string)
  end

  # Return an uncompressed version of a compressed string.
  def unzip(string)
    Zlib::Inflate.inflate(string)
  end

end

