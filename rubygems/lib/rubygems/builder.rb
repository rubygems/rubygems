module Gem

  ##
  # The Builder class processes RubyGem specification files
  # to produce a .gem file.
  #
  class Builder
  require 'stringio'

    ##
    # Builder::FileContents is the file contents
    #
    class FileContents < StringIO
      def add_ruby_header
        self.puts <<-EOS
        MD5SUM = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
        if $0 == __FILE__
          require 'optparse'
        
          options = {}
          ARGV.options do |opts|
            opts.on_tail("--help", "show this message") {puts opts; exit}
            opts.on('--dir=DIRNAME', "Installation directory for the Gem") {|options[:directory]|}
            opts.on('--force', "Force Gem to intall, bypassing dependency checks") {|options[:force]|}
            opts.parse!
          end

          require 'rubygems'
          @directory = options[:directory] || Gem.dir  
          @force = options[:force]
  
          Gem::Installer.new(__FILE__).install(@force, @directory)      
end

__END__
        EOS
      end
            
      ##
      # Reads the files listed in the specification and encodes
      # them into the provided file (IO)
      #
      # file:: [IO] the file to write the encoded data into
      #
      def write_files_to(files)
        require 'zlib'
        file_header = []
        files.each do |file_name|
          next if File.directory? file_name
          file_header << { "path" => file_name,
                          "size" => File.size(file_name),
                          "mode" => File.stat(file_name).mode & 0777
          }
        end
        self.puts file_header.to_yaml
        file_header.each do |entry|
          data = [Zlib::Deflate.deflate(File.read(entry['path']))].pack("m")
          self.puts "---"
          self.puts data
        end
      end
      def md5
        MD5.md5(string)
      end    
    end

    ##
    # Constructs a builder instance for the provided specification
    #
    # spec:: [Gem::Specification] The specification instance
    #
    def initialize(spec)
      @spec = spec
    end
    
    ##
    # Builds the gem from the specification
    #
    def build
      require 'yaml'
      require 'md5'
      require 'stringio' 
      
      file_name = @spec.full_name+".gem"
      file_contents = FileContents.new
      
      file_contents.add_ruby_header
      file_contents.puts(@spec.to_yaml)
      file_contents.write_files_to(@spec.files)
      puts success
      md5 = file_contents.md5
      File.open(file_name, "w") do |file|
        file.write(file_contents.string.gsub(/MD5SUM =.*$/, "MD5SUM = \"#{md5.to_s}\""))
      end 
    end
    
    def success
      <<-EOM
  Successfully built RubyGem
  Name: #{@spec.name}
  Version: #{@spec.version}
  File: #{@spec.full_name+'.gem'}"
EOM
    end
  end
end
