module Gem

  ##
  # Validator performs various gem file and gem database validation
  class Validator

    ##
    # Given a gem file's contents, validates against is own MD5 checksum
    # 
    # gem_data:: [String] Contents of the gem file
    def verify_gem(gem_data)
      if(gem_data.size == 0) then
        raise "Empty Gem file"
      end
      require 'md5'
      unless (MD5.md5(gem_data.gsub(/MD5SUM = "([a-z0-9]+)"/, "MD5SUM = \"" + ("F" * 32) + "\"")) == $1.to_s) 
        raise "Invalid checksum for Gem file"
      end
    end

    private
    def display_alien_report(errors)
      errors.each do |key, val|
        if(val.size > 0) then 
          puts "#{key} has #{val.size} problems"
        else 
          puts "#{key} is error-free"
        end
        val.each do |error_entry|
          puts "\t#{error_entry.path}:"
          puts "\t#{error_entry.problem}"
          puts
        end
        puts
      end
    end
  
    def find_files_for_gem(gem_directory)
      installed_files = []
      Find.find(gem_directory) {|file_name|
        file_name.slice!((gem_directory.size)..(file_name.size-1)).sub(/^\//, "")
        Find.prune if (file_name =~ /CVS/ || File.directory?(file_name) || file_name == "")
        installed_files << file_name
      }
      installed_files
    end
 

    public 
    ErrorData = Struct.new(:path, :problem)

    ##
    # Checks the gem directory for the following potential 
    # inconsistencies/problems:
    # * Checksum gem itself
    # * For each file in each gem, check consistency of installed versions
    # * Check for files that aren't part of the gem but are in the gems directory
    # * 1 cache - 1 spec - 1 directory.  
    def alien
      puts "Checking gem database for inconsistencies"
      require 'rubygems/installer'
      require 'find'
      require 'md5'
      errors = {}
      Gem::Cache.from_installed_gems.each do |gem_name, gem_spec|
        errors[gem_name] ||= []
        gem_path = File.join(Gem.dir, "cache", gem_spec.full_name) + ".gem"
        spec_path = File.join(Gem.dir, "specifications", gem_spec.full_name) + ".gemspec"
        gem_directory = File.join(Gem.dir, gem_spec.full_name)
    
        installed_files = find_files_for_gem(gem_directory)
    
        if(!File.exist?(spec_path)) then
          errors[gem_name] << ErrorData.new(spec_path, "Spec file doesn't exist for installed gem")
        end
    
        # Need to factor read_files_from_gem out into some kind of
        # Gem file reader/writer class probably.
        begin
          verify(File.read(gem_path)) 
          File.open(gem_path) do |file|
            installer = Gem::Installer.new(gem_name)
            installer.skip_ruby(file)
            installer.read_spec(file)
            installer.read_files_from_gem(file) do |entry, data|
              # Found this file.  Delete it from list
	      installed_files.delete entry['path']
              unless MD5.md5(File.read(File.join(gem_directory, entry['path']))).to_s == MD5.md5(data).to_s
	        errors[gem_name] << ErrorData.new(entry['path'], "installed file doesn't match original from gem")
              end
            end
          end
        rescue => e
          errors[gem_name] << ErrorData.new(gem_path, e.message)
        end
    
        if(installed_files.size > 0) then
          errors[gem_name] << ErrorData.new(gem_path, "Unmanaged files in gem: #{installed_files.inspect}")
        end
    
      end
      display_alien_report(errors)
    end
  end
end
