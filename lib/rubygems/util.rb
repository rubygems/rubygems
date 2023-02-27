# frozen_string_literal: true
require_relative "deprecate"

##
# This module contains various utility methods as module methods.

module Gem::Util

  ##
  # Zlib::GzipReader wrapper that unzips +data+.

  def self.gunzip(data)
    require "zlib"
    require "stringio"
    data = StringIO.new(data, "r")

    gzip_reader = begin
                    Zlib::GzipReader.new(data)
                  rescue Zlib::GzipFile::Error => e
                    raise e.class, e.inspect, e.backtrace
                  end

    unzipped = gzip_reader.read
    unzipped.force_encoding Encoding::BINARY
    unzipped
  end

  ##
  # Zlib::GzipWriter wrapper that zips +data+.

  def self.gzip(data)
    require "zlib"
    require "stringio"
    zipped = StringIO.new(String.new, "w")
    zipped.set_encoding Encoding::BINARY

    Zlib::GzipWriter.wrap zipped do |io|
      io.write data
    end

    zipped.string
  end

  ##
  # A Zlib::Inflate#inflate wrapper

  def self.inflate(data)
    require "zlib"
    Zlib::Inflate.inflate data
  end

  ##
  # This calls IO.popen and reads the result

  def self.popen(*command)
    IO.popen command, &:read
  end

  ##
  # Invokes system, but silences all output.

  def self.silent_system(*command)
    opt = { :out => IO::NULL, :err => [:child, :out] }
    if Hash === command.last
      opt.update(command.last)
      cmds = command[0...-1]
    else
      cmds = command.dup
    end
    system(*(cmds << opt))
  end

  class << self
    extend Gem::Deprecate

    rubygems_deprecate :silent_system
  end

  ##
  # Enumerates the parents of +directory+.

  def self.traverse_parents(directory, &block)
    return enum_for __method__, directory unless block_given?

    here = File.expand_path directory
    loop do
      Dir.chdir here, &block rescue Errno::EACCES

      new_here = File.expand_path("..", here)
      return if new_here == here # toplevel
      here = new_here
    end
  end

  ##
  # Globs for files matching +pattern+ inside of +directory+,
  # returning absolute paths to the matching files.

  def self.glob_files_in_dir(glob, base_path)
    Dir.glob(glob, base: base_path).map! {|f| File.expand_path(f, base_path) }
  end

  ##
  # Corrects +path+ (usually returned by `URI.parse().path` on Windows), that
  # comes with a leading slash.

  def self.correct_for_windows_path(path)
    if path[0].chr == "/" && path[1].chr =~ /[a-z]/i && path[2].chr == ":"
      path[1..-1]
    else
      path
    end
  end

  class DefaultKey
  end

  class PrivateType
  end

  require "date"
  SAFE_MARSHAL_CLASSES = [
    Array,
    Date,
    Float,
    Hash,
    Integer,
    String,
    Symbol,
    Time,

    TrueClass,
    FalseClass,

    NilClass,

    Gem::Dependency,
    Gem::NameTuple,
    Gem::Platform,
    Gem::Requirement,
    Gem::Specification,
    Gem::Version,

    DefaultKey,
    PrivateType,
  ].freeze
  SAFE_MARSHAL_ERROR = "Unexpected class %s present in marshaled data. Only %s are allowed."
  SAFE_MARSHAL_PROC = proc do |object|
    object.tap do
      unless SAFE_MARSHAL_CLASSES.include?(object.class)
        raise TypeError, format(SAFE_MARSHAL_ERROR, object.class, SAFE_MARSHAL_CLASSES.join(", "))
      end
    end
  end

  private_constant :SAFE_MARSHAL_CLASSES, :SAFE_MARSHAL_ERROR, :SAFE_MARSHAL_PROC

  def self.safe_load_marshal(data)
    Marshal.load(data, SAFE_MARSHAL_PROC)
  end
end
