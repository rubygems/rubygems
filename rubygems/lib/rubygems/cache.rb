module Gem

  class Cache
    def initialize(specifications)
      @gems = specifications
    end

    def self.from_installed_gems(source_dir = File.join(Gem.dir, "specifications"))
      require 'yaml'
      gems = {}
      Dir[File.join(source_dir, "*")].each do |file_name|
        gem = YAML.load(File.read(file_name))
        key = File.basename(file_name).gsub(/\.gemspec/, "")
        gems[key] = gem
      end
      self.new(gems)
    end

    def each(&block)
      @gems.each(&block)
    end

    def search_by_name(gem_name)
      result = []
      @gems.each do |key, value|
         if(key =~ /#{gem_name}/) then
           result << value
         end
      end
      result
    end
  end
  
end