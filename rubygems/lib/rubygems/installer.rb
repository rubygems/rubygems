module Gem

  ##
  # The installer class processes RubyGem .gem files and installs
  # the files contained in the .gem into the $GEM_PATH.
  #
  class Installer
  
    ##
    # Constructs a Installer instance
    #
    # gem:: [String] The file name of the gem
    #
    def initialize(gem)
      @gem = gem
    end
    
    ##
    # Installs the gem in the $GEM_PATH.  This will fail (unless force=true)
    # if a Gem has a requirement on another Gem that is not installed.  The
    # installation will install in the following structure:
    #
    #  $GEM_PATH/
    #      specifications/<gem-version>.gemspec #=> the extracted YAML gemspec
    #      <gem-version>/... #=> the extracted Gem files
    #      cache/<gem-version>.gem #=> a cached copy of the installed Gem
    # 
    # force:: [default = false] if false will fail if a required Gem is not installed
    #
    def install(force=false)
      require 'fileutils'
      File.open(@gem, 'r') do |file|
        skip_ruby(file)
        spec = read_spec(file)
        unless force
          spec.dependencies.each do |dep_gem|
            require_gem(dep_gem)
          end
        end
        directory = File.join(Gem.dir, spec.full_name)
        FileUtils.mkdir_p directory
        extract_files(directory, file)
        write_spec(spec, File.join(Gem.dir, "specifications"))
        FileUtils.cp(@gem, File.join(Gem.dir, "cache"))
        puts "Successfully installed #{spec.name} version #{spec.version}"
      end
    end
    
    private
    
    ##
    # Skips the Ruby self-install header.  After calling this method, the
    # IO index will be set after the Ruby code.
    #
    # file:: [IO] The IO to process (skip the Ruby code)
    #
    def skip_ruby(file)
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
    def read_spec(file)
      require 'yaml'
      yaml = ''
      read_until_dashes(file) do |line|
        yaml << line
      end
      YAML.load(yaml)
    end
    
    ##
    # Writes the .gemspec specification (in Ruby) to the supplied spec_path.
    #
    # spec:: [Gem::Specification] The Gem specification to output
    # spec_path:: [String] The location (path) to write the gemspec to
    #
    def write_spec(spec, spec_path)
      File.open(File.join(spec_path, spec.full_name+".gemspec"), "w") do |file|
        file.puts spec.to_ruby
      end
    end
    
    ##
    # Reads lines from the supplied IO until a end-of-yaml (---) is
    # reached
    #
    # file:: [IO] The IO to process
    # block:: [String] The read line
    #
    def read_until_dashes(file)
      while((line = file.gets) && line.chomp.strip != "---") do
        yield line
      end
    end
    
    ##
    # Reads the YAML file index and then extracts each file
    # into the supplied directory, building directories for the
    # extracted files as needed.
    #
    # directory:: [String] The root directory to extract files into
    # file:: [IO] The IO that contains the file data
    #
    def extract_files(directory, file)
      require 'zlib'
      require 'fileutils'
      require 'yaml'
      wd = Dir.getwd
      Dir.chdir directory
      begin
        header_yaml = ''
        read_until_dashes(file) do |line|
          header_yaml << line
        end
        header = YAML.load(header_yaml)
        header.each do |entry|
          path = entry['path']
          mode = entry['mode']
          FileUtils.mkdir_p File.dirname(path)
          file_data = ''
          read_until_dashes(file) do |line|
            file_data << line
          end
          File.open(path, "wb") do |out|
            out.write Zlib::Inflate.inflate(file_data.strip.unpack("m")[0])
          end
        end
      ensure
        Dir.chdir wd
      end
    end
  end
  
  ##
  # The Uninstaller class uninstalls a Gem
  #
  class Uninstaller
  
    ##
    # Constructs and Uninstaller instance
    # 
    # gem:: [String] The Gem name to uninstall
    #
    def initialize(gem)
      @gem = gem
    end
    
    ##
    # Performs the uninstall of the Gem.  This removes the spec, the Gem
    # directory, and the cached .gem file.
    #
    def uninstall
      require 'yaml'
      require 'fileutils'
      list = Dir.glob(File.join(Gem.dir, "specifications", "#{@gem}-*.gemspec"))
      if list.size==0
        puts "Unknown RubyGem: #{@gem}"
      elsif list.size>1
        #choose from list
      else
        spec = eval(File.read(list[0]))
        FileUtils.rm_rf list
        FileUtils.rm_rf File.join(Gem.dir, spec.full_name)
        FileUtils.rm_rf File.join(Gem.dir, "cache", "#{spec.full_name}.gem")
        puts "Successfully uninstalled #{spec.name} version #{spec.version}"
      end
    end
  end
  
end
