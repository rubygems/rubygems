require 'rubygems/package'

module Gem

  ##
  # Used to raise parsing and loading errors
  #
  class FormatException < Gem::Exception
    attr_accessor :file_path
    #I go back and forth on whether or not to create custom exception classes
  end

  ##
  # The format class knows the guts of the RubyGem .gem file format
  # and provides the capability to read gem files
  #
  class Format
    attr_accessor :spec, :file_entries, :gem_path
  
    ##
    # Constructs an instance of a Format object, representing the gem's
    # data structure.
    #
    # gem:: [String] The file name of the gem
    #
    def initialize(gem_path)
      @gem_path = gem_path
    end
    
    ##
    # Reads the named gem file and returns a Format object, representing 
    # the data from the gem file
    #
    # file_path:: [String] Path to the gem file
    #
    def self.from_file_by_path(file_path)
      if(!File.exist?(file_path)) then
        exception = FormatException.new("Cannot load gem\nFile not found")
        exception.file_path = file_path
        raise exception
      end
      require 'fileutils'
      f = File.open(file_path, 'rb')
      from_io(f, file_path)
    end

    ##
    # Reads a gem from an io stream and returns a Format object, representing
    # the data from the gem file
    #
    # io:: [IO] Stream from which to read the gem
    #
    def self.from_io(io, gem_path="(io)")
      format = self.new(gem_path)
      Package.open_from_io(io) do |pkg|
        format.spec = pkg.metadata
        format.file_entries = []
        pkg.each do |entry|
          format.file_entries << [{"size", entry.size, "mode", entry.mode,
              "path", entry.full_name}, entry.read]
        end
      end
      format
    end

  end
end
