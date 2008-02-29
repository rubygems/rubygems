#++
# Copyright (C) 2004 Mauricio Julio Fernández Pradier
# See LICENSE.txt for additional licensing information.
#--

require 'rubygems/package'

class Gem::Package::TarReader

  include Gem::Package

  class UnexpectedEOF < StandardError; end

  class Entry
    Gem::Package::TarHeader::FIELDS.each { |x| attr_reader x }

    def initialize(header, io)
      @io = io
      @name = header.name
      @mode = header.mode
      @uid = header.uid
      @gid = header.gid
      @size = header.size
      @mtime = header.mtime
      @checksum = header.checksum
      @typeflag = header.typeflag
      @linkname = header.linkname
      @magic = header.magic
      @version = header.version
      @uname = header.uname
      @gname = header.gname
      @devmajor = header.devmajor
      @devminor = header.devminor
      @prefix = header.prefix
      @read = 0
      @orig_pos = @io.pos
    end

    def read(len = nil)
      return nil if @read >= @size
      len ||= @size - @read
      max_read = [len, @size - @read].min
      ret = @io.read(max_read)
      @read += ret.size
      ret
    end

    def getc
      return nil if @read >= @size
      ret = @io.getc
      @read += 1 if ret
      ret
    end

    def is_directory?
      @typeflag == "5"
    end

    def is_file?
      @typeflag == "0"
    end

    def eof?
      @read >= @size
    end

    def pos
      @read
    end

    def rewind
      raise Gem::Package::NonSeekableIO unless @io.respond_to? :pos=

      @io.pos = @orig_pos
      @read = 0
    end

    alias_method :is_directory, :is_directory?
    alias_method :is_file, :is_file?

    def bytes_read
      @read
    end

    def full_name
      if @prefix != "" then
        File.join(@prefix, @name)
      else
        @name
      end
    end

    def close
      invalidate
    end

    private

    # HACK use a flag
    def invalidate
      extend InvalidEntry
    end

  end

  module InvalidEntry

    def read(len=nil)
      raise Gem::Package::ClosedIO
    end

    def getc()
      raise Gem::Package::ClosedIO
    end

    def rewind()
      raise Gem::Package::ClosedIO
    end

  end

  def self.new(io)
    reader = super

    return reader unless block_given?

    begin
      yield reader
    ensure
      reader.close
    end

    nil
  end

  def initialize(io)
    @io = io
    @init_pos = io.pos
  end

  def close
  end

  def each(&block)
    each_entry(&block)
  end

  def each_entry
    loop do
      return if @io.eof?
      header = Gem::Package::TarHeader.new_from_stream @io
      return if header.empty?
      entry = Entry.new header, @io
      size = entry.size
      yield entry
      skip = (512 - (size % 512)) % 512
      if @io.respond_to? :seek
        # avoid reading...
        @io.seek(size - entry.bytes_read, IO::SEEK_CUR)
      else
        pending = size - entry.bytes_read
        while pending > 0
          bread = @io.read([pending, 4096].min).size
          raise UnexpectedEOF if @io.eof?
          pending -= bread
        end
      end

      @io.read(skip) # discard trailing zeros

      # make sure nobody can use #read, #getc or #rewind anymore
      entry.close
    end
  end

  # do not call this during a #each or #each_entry iteration
  def rewind
    if @init_pos == 0 then
      raise Gem::Package::NonSeekableIO unless @io.respond_to? :rewind
      @io.rewind
    else
      raise Gem::Package::NonSeekableIO unless @io.respond_to? :pos=
      @io.pos = @init_pos
    end
  end

end

