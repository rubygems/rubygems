module Gem

  class Installer
    def initialize(gem)
      @gem = gem
    end
    
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
        extract_data(directory, file)
        write_spec(spec, File.join(Gem.dir, "specifications"))
        FileUtils.cp(@gem, File.join(Gem.dir, "cache"))
        puts "Successfully installed #{spec.name} version #{spec.version}"
      end
    end
    
    private
    
    def skip_ruby(file)
      while(file.gets.chomp != "__END__") do
      end
    end
    
    def write_spec(spec, location)
      require 'yaml'
      File.open(File.join(location, spec.full_name+".gemspec"), "w") do |file|
        file.puts spec.to_yaml
      end
    end
    
    def read_spec(file)
      require 'yaml'
      yaml = ''
      read_until_dashes(file) do |line|
        yaml << line
      end
      YAML.load(yaml)
    end
    
    def read_until_dashes(file)
      while((line = file.gets) && line.chomp.strip != "---") do
        yield line
      end
    end
    
    def extract_data(directory, file)
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
  
  class Uninstaller
    def initialize(gem)
      @gem = gem
    end
    
    def uninstall
      require 'yaml'
      require 'fileutils'
      list = Dir.glob(File.join(Gem.dir, "specifications", "#{@gem}-*.gemspec"))
      if list.size==0
        puts "Unknown RubyGem: #{@gem}"
      elsif list.size>1
        #choose from list
      else
        spec = YAML.load(File.read(list[0]))
        FileUtils.rm_rf list
        FileUtils.rm_rf File.join(Gem.dir, spec.full_name)
        FileUtils.rm_rf File.join(Gem.dir, "cache", "#{spec.full_name}.gem")
        puts "Successfully uninstalled #{spec.name} version #{spec.version}"
      end
    end
  end
  
end
