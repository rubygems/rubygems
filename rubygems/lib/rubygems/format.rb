module Gem

  ##
  # Used to raise parsing and loading errors
  #
  class FormatException < Exception
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
      File.open(file_path, 'r') do |file|
        from_io(file, file_path)
      end
    end

    ##
    # Reads a gem from an io stream and returns a Format object, representing
    # the data from the gem file
    #
    # io:: [IO] Stream from which to read the gem
    #
    def self.from_io(io, gem_path="(io)")
      format = self.new(gem_path)
      skip_ruby(io)
      format.spec = read_spec(io)
      format.file_entries = []
      read_files_from_gem(io) do |entry, file_data|
        format.file_entries << [entry, file_data]
      end
      format
    end
    
    private 
    ##
    # Skips the Ruby self-install header.  After calling this method, the
    # IO index will be set after the Ruby code.
    #
    # file:: [IO] The IO to process (skip the Ruby code)
    #
    def self.skip_ruby(file)
      end_seen = false
      loop {
        line = file.gets
        if(line == nil || line.chomp == "__END__") then
          end_seen = true
          break
        end
      }
     if(end_seen == false) then
       raise FormatException.new("Failed to find end of ruby script while reading gem")
     end
    end
     
    ##
    # Reads the specification YAML from the supplied IO and constructs
    # a Gem::Specification from it.  After calling this method, the
    # IO index will be set after the specification header.
    #
    # file:: [IO] The IO to process
    #
    def self.read_spec(file)
      require 'yaml'
      yaml = ''
      begin
        read_until_dashes(file) do |line|
          yaml << line
        end
        YAML.load(yaml)
      rescue ArgumentError => e
        raise FormatException.new("Failed to parse gem specification out of gem file")
      end
    end
    
    ##
    # Reads lines from the supplied IO until a end-of-yaml (---) is
    # reached
    #
    # file:: [IO] The IO to process
    # block:: [String] The read line
    #
    def self.read_until_dashes(file)
      while((line = file.gets) && line.chomp.strip != "---") do
        yield line
      end
    end


    ##
    # Reads the embedded file data from a gem file, yielding an entry
    # containing metadata about the file and the file contents themselves
    # for each file that's archived in the gem.
    # NOTE: Many of these methods should be extracted into some kind of
    # Gem file read/writer
    #
    # gem_file:: [IO] The IO to process
    #
    def self.read_files_from_gem(gem_file)
      require 'zlib'
      require 'yaml'
      header_yaml = ''
      begin
        self.read_until_dashes(gem_file) do |line|
          header_yaml << line
        end
        header = YAML.load(header_yaml)
        header.each do |entry|
          file_data = ''
          self.read_until_dashes(gem_file) do |line|
            file_data << line
          end
          yield [entry, Zlib::Inflate.inflate(file_data.strip.unpack("m")[0])]
        end
      rescue Exception => e
        raise FormatException.new("Error reading files from gem")
      end
    end
  end
end
