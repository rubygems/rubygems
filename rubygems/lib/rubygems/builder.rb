require "rubygems/package"
require "yaml"

module Gem

  ##
  # The Builder class processes RubyGem specification files
  # to produce a .gem file.
  #
  class Builder
  
    include UserInteraction
    ##
    # Constructs a builder instance for the provided specification
    #
    # spec:: [Gem::Specification] The specification instance
    #
    def initialize(spec)
      @spec = spec
    end
    
    ##
    # Builds the gem from the specification.  Returns the name of the file written.
    #
    def build
      @spec.mark_version
      @spec.validate
      
      file_name = @spec.full_name+".gem"

      Package.open(file_name, "w") do |pkg|
          pkg.metadata = @spec.to_yaml
          @spec.files.each do |file|
              next if File.directory? file
              pkg.add_file_simple(file, File.stat(file_name).mode & 0777,
                                  File.size(file)) do |os|
                                      os.write File.open(file, "rb"){|f|f.read}
                                  end
          end
      end
      say success
      file_name
    end
    
    def success
      <<-EOM
  Successfully built RubyGem
  Name: #{@spec.name}
  Version: #{@spec.version}
  File: #{@spec.full_name+'.gem'}
EOM
    end
  end
end
