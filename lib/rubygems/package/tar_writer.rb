#++
# Copyright (C) 2004 Mauricio Julio Fernández Pradier
# See LICENSE.txt for additional licensing information.
#--

require 'rubygems/package'

class Gem::Package::TarWriter

  class FileOverflow < StandardError; end

  class BoundedStream

    attr_reader :limit, :written

    def initialize(io, limit)
      @io = io
      @limit = limit
      @written = 0
    end

    def write(data)
      if data.size + @written > @limit
        raise FileOverflow,
                "You tried to feed more data than fits in the file."
      end
      @io.write data
      @written += data.size
      data.size
    end

  end

  class RestrictedStream

    def initialize(io)
      @io = io
    end

    def write(data)
      @io.write data
    end

  end

  def self.new(io)
    writer = super

    return writer unless block_given?

    begin
      yield writer
    ensure
      writer.close
    end

    nil
  end

  def initialize(io)
    @io = io
    @closed = false
  end

  def add_file(name, mode)
    raise ArgumentError, 'block not supplied' unless block_given?
    raise Gem::Package::ClosedIO if @closed
    raise Gem::Package::NonSeekableIO unless @io.respond_to? :pos=
    name, prefix = split_name(name)
    init_pos = @io.pos
    @io.write "\0" * 512 # placeholder for the header
    yield RestrictedStream.new(@io)
    #FIXME: what if an exception is raised in the block?
    #FIXME: what if an exception is raised in the block?
    size = @io.pos - init_pos - 512
    remainder = (512 - (size % 512)) % 512
    @io.write("\0" * remainder)
    final_pos = @io.pos
    @io.pos = init_pos

    header = Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                         :size => size, :prefix => prefix).to_s

    @io.write header
    @io.pos = final_pos
  end

  def add_file_simple(name, mode, size)
    raise ArgumentError, 'block not supplied' unless block_given?
    raise Gem::Package::ClosedIO if @closed

    name, prefix = split_name(name)
    header = Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                         :size => size, :prefix => prefix).to_s

    @io.write header
    os = BoundedStream.new(@io, size)

    yield os

    #FIXME: what if an exception is raised in the block?
    min_padding = size - os.written
    @io.write("\0" * min_padding)
    remainder = (512 - (size % 512)) % 512
    @io.write("\0" * remainder)
  end

  def close
    #raise ClosedIO if @closed
    return if @closed
    @io.write "\0" * 1024
    @closed = true
  end

  def flush
    raise Gem::Package::ClosedIO if @closed
    @io.flush if @io.respond_to? :flush
  end

  def mkdir(name, mode)
    raise Gem::Package::ClosedIO if @closed
    name, prefix = split_name(name)
    header = Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                         :typeflag => "5", :size => 0,
                                         :prefix => prefix).to_s
    @io.write header
    nil
  end

  private

  def split_name name
    raise Gem::Package::TooLongFileName if name.size > 256

    if name.size <= 100 then
      prefix = ""
    else
      parts = name.split(/\//)
      newname = parts.pop
      nxt = ""

      loop do
        nxt = parts.pop
        break if newname.size + 1 + nxt.size > 100
        newname = nxt + "/" + newname
      end

      prefix = (parts + [nxt]).join "/"
      name = newname

      if name.size > 100 or prefix.size > 155 then
        raise Gem::Package::TooLongFileName 
      end
    end

    return name, prefix
  end

end

