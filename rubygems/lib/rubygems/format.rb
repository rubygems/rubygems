module Gem

  ##
  # The format class knows the guts of the RubyGem .gem file format
  # and provides the capability to read gem files
  #
  class Format
    attr_accessor :spec, :file_entries, :gem_path
  
    ##
    # Constructs a Installer instance
    #
    # gem:: [String] The file name of the gem
    #
    def initialize(gem_path)
      @gem_path = gem_path
    end
    
    ##
    # Reads a gem file and returns a Format object, representing the data
    # from the gem file
    #
    # file_path:: [String] Path to the gem file
    #
    def self.from_file(file_path)
      require 'fileutils'
      gem = self.new(file_path)
      File.open(file_path, 'r') do |file|
        skip_ruby(file)
        gem.spec = read_spec(file)
        gem.file_entries = []
        read_files_from_gem(file) do |entry, file_data|
          gem.file_entries << [entry, file_data]
        end
      end
      return gem
    end
    
    private 
    ##
    # Skips the Ruby self-install header.  After calling this method, the
    # IO index will be set after the Ruby code.
    #
    # file:: [IO] The IO to process (skip the Ruby code)
    #
    def self.skip_ruby(file)
      while(file.gets.chomp != "__END__") do
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
      read_until_dashes(file) do |line|
        yaml << line
      end
      YAML.load(yaml)
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
    end
  end
end
