module Gem

  ##
  # The cache class is used to hold all the specifications
  # in a provided location ($GEM_PATH) for iteration/searching.
  #
  class Cache
    
    ##
    # Constructs a cache instance with the provided specifications
    #
    # specifications:: [Array] array of Gem::Specification objects
    #
    def initialize(specifications)
      @gems = specifications
    end
    
    
    ##
    # Factory method to construct a cache instance for a provided path
    # 
    # source_dir:: [default=Gem.dir+'specifications'] The path to search for specifications
    # return:: Cache instance
    #
    def self.from_installed_gems(source_dir = File.join(Gem.dir, "specifications"))
      gems = {}
      Dir[File.join(source_dir, "*")].each do |file_name|
        begin
          gem = eval(File.read(file_name))
        rescue
          raise "Could not read .gemspec from cache: #{source_dir}"
        end
        key = File.basename(file_name).gsub(/\.gemspec/, "")
        gems[key] = gem
      end
      self.new(gems)
    end

    ##
    # Iterate over the specifications in the cache
    #
    # &block:: [yields Gem::Specification]
    #
    def each(&block)
      @gems.each(&block)
    end
    
    ##
    # Searches for all specifications that match the provided name
    #
    # gem_name:: [String] The name of the gem (name includes string)
    # return:: [Array] specification list
    #
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