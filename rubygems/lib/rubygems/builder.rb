module Gem

  ##
  # The Builder class processes RubyGem specification files
  # to produce a .gem file.
  #
  class Builder
  
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
      File.open(@spec.full_name+".gem", "w") do |file|
        ruby_header(file)
        file.puts @spec.to_yaml
        write_files_to(file)
        puts "Successfully built RubyGem\n  Name: #{@spec.name}\n  Version: #{@spec.version}\n  File: #{@spec.full_name+'.gem'}"
      end
    end
    
    ##
    # Reads the files listed in the specification and encodes
    # them into the provided file (IO)
    #
    # file:: [IO] the file to write the encoded data into
    #
    def write_files_to(file)
      require 'zlib'
      file_header = []
      @spec.files.each do |file_name|
        next if File.directory? file_name
        file_header << { "path" => file_name,
                         "size" => File.size(file_name),
                         "mode" => File.stat(file_name).mode & 0777
                       }
      end
      file.puts file_header.to_yaml
      file_header.each do |entry|
        data = [Zlib::Deflate.deflate(File.read(entry['path']))].pack("m")
        file.puts "---"
        file.puts data
      end
    end
    
    def ruby_header(file)
      file.puts <<-EOS
if $0 == __FILE__
  require 'getoptlong'
  require 'rubygems'
  
  opts = GetoptLong.new([ '--force', '-f', GetoptLong::NO_ARGUMENT ])
  @force = false
  opts.each do |opt, arg|
    case opt
    when '--force'
      @force = true
    end
  end
  Gem::Installer.new(__FILE__).install(@force)      
end
__END__
EOS
    end
  end
  
end
