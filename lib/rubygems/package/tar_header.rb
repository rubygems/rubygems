#++
# Copyright (C) 2004 Mauricio Julio Fernández Pradier
# See LICENSE.txt for additional licensing information.
#--

require 'rubygems/package'

class Gem::Package::TarHeader

  FIELDS = [
    :name, :mode, :uid, :gid, :size, :mtime, :checksum, :typeflag,
    :linkname, :magic, :version, :uname, :gname, :devmajor,
    :devminor, :prefix
  ]

  FIELDS.each { |x| attr_reader x }

  def self.new_from_stream(stream)
    data = stream.read(512)
    fields = data.unpack("A100" +   # record name
                         "A8A8A8" + # mode, uid, gid
                         "A12A12" + # size, mtime
                         "A8A" +    # checksum, typeflag
                         "A100" +   # linkname
                         "A6A2" +   # magic, version
                         "A32" +    # uname
                         "A32" +    # gname
                         "A8A8" +   # devmajor, devminor
                         "A155")    # prefix
    name = fields.shift
    mode = fields.shift.oct
    uid = fields.shift.oct
    gid = fields.shift.oct
    size = fields.shift.oct
    mtime = fields.shift.oct
    checksum = fields.shift.oct
    typeflag = fields.shift
    linkname = fields.shift
    magic = fields.shift
    version = fields.shift.oct
    uname = fields.shift
    gname = fields.shift
    devmajor = fields.shift.oct
    devminor = fields.shift.oct
    prefix = fields.shift

    empty = (data == "\0" * 512)

    new(:name=>name, :mode=>mode, :uid=>uid, :gid=>gid, :size=>size,
        :mtime=>mtime, :checksum=>checksum, :typeflag=>typeflag,
        :magic=>magic, :version=>version, :uname=>uname, :gname=>gname,
        :devmajor=>devmajor, :devminor=>devminor, :prefix=>prefix,
        :empty => empty)
  end

  def initialize(vals)
    unless vals[:name] && vals[:size] && vals[:prefix] && vals[:mode] then
      raise ArgumentError, ":name, :size, :prefix and :mode required"
    end

    vals[:uid] ||= 0
    vals[:gid] ||= 0
    vals[:mtime] ||= 0
    vals[:checksum] ||= ""
    vals[:typeflag] ||= "0"
    vals[:magic] ||= "ustar"
    vals[:version] ||= "00"
    vals[:uname] ||= "wheel"
    vals[:gname] ||= "wheel"
    vals[:devmajor] ||= 0
    vals[:devminor] ||= 0

    FIELDS.each { |x| instance_variable_set "@#{x.to_s}", vals[x] }

    @empty = vals[:empty]
  end

  def empty?
    @empty
  end

  def to_s
    update_checksum
    header checksum
  end

  def update_checksum
    h = header(" " * 8)
    @checksum = oct(calculate_checksum(h), 6)
  end

  private

  def calculate_checksum(hdr)
    hdr.unpack("C*").inject{|a,b| a+b}
  end

  ##
  #--
  # struct tarfile_entry_posix {
  #   char name[100];   # ASCII + (Z unless filled)
  #   char mode[8];     # 0 padded, octal, null
  #   char uid[8];      # ditto
  #   char gid[8];      # ditto
  #   char size[12];    # 0 padded, octal, null
  #   char mtime[12];   # 0 padded, octal, null
  #   char checksum[8]; # 0 padded, octal, null, space
  #   char typeflag[1]; # file: "0"  dir: "5"
  #   char linkname[100]; # ASCII + (Z unless filled)
  #   char magic[6];      # "ustar\0"
  #   char version[2];    # "00"
  #   char uname[32];     # ASCIIZ
  #   char gname[32];     # ASCIIZ
  #   char devmajor[8];   # 0 padded, octal, null
  #   char devminor[8];   # o padded, octal, null
  #   char prefix[155];   # ASCII + (Z unless filled)
  # };
  #++

  def header(chksum)
    arr = [name, oct(mode, 7), oct(uid, 7), oct(gid, 7), oct(size, 11),
      oct(mtime, 11), chksum, " ", typeflag, linkname, magic, version,
      uname, gname, oct(devmajor, 7), oct(devminor, 7), prefix]
    str = arr.pack("a100a8a8a8a12a12" + # name, mode, uid, gid, size, mtime
                   "a7aaa100a6a2" + # chksum, typeflag, linkname, magic, version
                   "a32a32a8a8a155") # uname, gname, devmajor, devminor, prefix
    str + "\0" * ((512 - str.size) % 512)
  end

  def oct(num, len)
    "%0#{len}o" % num
  end

end

