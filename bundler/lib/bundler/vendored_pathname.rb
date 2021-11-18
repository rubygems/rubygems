# frozen_string_literal: true

#
# Pure ruby implementation of the C-extension of the `pathname` gem.
#
module Bundler
  def Pathname(str) # rubocop:disable Naming/MethodName
    return str if str.is_a?(Bundler::Pathname)

    Pathname.new(str)
  end
  module_function :Pathname

  class Pathname
    attr_reader :path

    def initialize(path)
      path = path.to_path if path.respond_to? :to_path

      @path = String.new(path)
    end

    def eql?(other)
      self.class == other.class && path == other.path
    end

    alias_method :==, :eql?

    def hash
      path.hash
    end

    def to_s
      path
    end

    alias_method :to_path, :to_s

    def sub(*args, &block)
      self.class.new(path.sub(*args), &block)
    end

    def read(*args)
      File.read(path, *args)
    end

    def open(mode, &block)
      File.open(path, mode, &block)
    end

    def basename
      self.class.new(File.basename(path))
    end

    def dirname
      self.class.new(File.dirname(path))
    end

    def expand_path(base = Dir.pwd)
      self.class.new(File.expand_path(path, base))
    end

    def exist?
      File.exist?(path)
    end

    def directory?
      File.directory?(path)
    end

    def file?
      File.file?(path)
    end

    def size
      File.size(path)
    end

    #
    # The following methods are not used internally by bundler, but are provided
    # for backwards compatibility with the original Pathname class.
    #

    def freeze
      super
      path.freeze
      self
    end

    alias_method :===, :eql?

    def inspect
      "#<#{self.class.name}:#{path}>"
    end

    def sub_ext(repl)
      self.class.new(extname.empty? ? path + repl : path.sub(extname, repl))
    end

    def realpath
      self.class.new(File.realpath(path))
    end

    def realdirpath
      self.class.new(File.realdirpath(path))
    end

    def each_line(*args, &block)
      File.foreach(path, *args, &block)
    end

    def binread(*args)
      File.binread(path, *args)
    end

    def readlines(*args)
      File.readlines(path, *args)
    end

    def write(*args)
      File.write(path, *args)
    end

    def binwrite(*args)
      File.write(path, *args)
    end

    def sysopen(*args)
      IO.sysopen(path, *args)
    end

    def atime
      File.atime(path)
    end

    def birthtime
      File.birthtime(path)
    end

    def ctime
      File.ctime(path)
    end

    def mtime
      File.mtime(path)
    end

    def chmod(mode)
      File.chmod(mode, path)
    end

    def lchmod(mode)
      File.lchmod(mode, path)
    end

    def chown(owner, group)
      File.chowm(owner, group, path)
    end

    def lchown(owner, group)
      File.lchowm(owner, group, path)
    end

    def fnmatch(pattern, *args)
      File.fnmatch(pattern, path, *args)
    end

    def fnmatch?(pattern, *args)
      File.fnmatch?(pattern, path, *args)
    end

    def ftype
      File.ftype(path)
    end

    def make_link(old)
      File.link(old, path)
    end

    def readlink
      self.class.new(File.readlink(path))
    end

    def rename(to)
      File.rename(path, to)
    end

    def stat
      File.stat(path)
    end

    def lstat
      File.lstat(path)
    end

    def make_symlink(old)
      File.symlink(old, path)
    end

    def truncate(length)
      File.truncate(path, length)
    end

    def utime(atime, mtime)
      File.utime(atime, mtime, path)
    end

    def extname
      File.extname(path)
    end

    def split
      File.split(path).map {|str| self.class.new(str) }
    end

    def blockdev?
      FileTest.blockdev?(path)
    end

    def chardev?
      FileTest.chardev?(path)
    end

    def executable?
      FileTest.executable?(path)
    end

    def executable_real?
      FileTest.executable_real?(path)
    end

    def grpowned?
      FileTest.grpowned?(path)
    end

    def pipe?
      FileTest.pipe?(path)
    end

    def socket?
      FileTest.socket?(path)
    end

    def owned?
      FileTest.owned?(path)
    end

    def readable?
      FileTest.readable?(path)
    end

    def world_readable?
      FileTest.world_readable?(path)
    end

    def readable_real?
      FileTest.readable_real?(path)
    end

    def setuid?
      FileTest.setuid?(path)
    end

    def setgid?
      FileTest.setgid?(path)
    end

    def size?
      FileTest.size?(path)
    end

    def sticky?
      FileTest.sticky?(path)
    end

    def symlink?
      FileTest.symlink?(path)
    end

    def writable?
      FileTest.writable?(path)
    end

    def world_writable?
      FileTest.world_writable?(path)
    end

    def writable_real?
      FileTest.writable_real?(path)
    end

    def zero?
      FileTest.zero?(path)
    end

    def empty?
      FileTest.empty?(path)
    end

    def glob(pattern, flags = 0)
      Dir.glob(pattern, flags, :base => path).map {|str| self.class.new(str) }
    end

    def entries
      Dir.entries(path).map {|str| self.class.new(str) }
    end

    def mkdir(*args)
      Dir.mkdir(path, *args)
    end

    def rmdir
      Dir.mkdir(path)
    end

    def opendir(*args)
      Dir.opendir(path, *args)
    end

    def each_entry(*args, &block)
      Dir.foreach(path, *args, &block)
    end

    def unlink
      Dir.unlink(path)
    rescue Errno::ENOTDIR
      File.unlink(path)
    end

    alias_method :delete, :unlink

    undef_method :"=~"
  end
end

require_relative "vendor/pathname/lib/pathname"
