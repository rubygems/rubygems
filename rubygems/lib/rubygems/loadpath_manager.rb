module Kernel

  alias require__ require
  def require(file)
    unless Gem::LoadPathManager.search_loadpath(file).empty?
      return require__(file)
    end
    Gem::LoadPathManager.search_gempath(file)
    require__(file)
  end
end

module Gem
  module LoadPathManager
    module Gem
      class Specification
        def initialize(&block)
          @require_paths = ['lib']
          yield self
        end
        attr_reader :version
        attr_accessor :files, :require_paths, :name
        def platform=(platform)
          @platform = platform unless platform == "ruby"
        end
        def requirements; []; end
        def version=(version)
          @version = ::Gem::Version.create(version)
        end
        def full_name
          @full_name ||= "#{@name}-#{@version}#{@platform ? "-#{@platform}" : ''}"
        end
        def method_missing(method, *args)
        end
        def <=>(other)
          r = @name<=>other.name
          r = other.version<=>@version if r == 0
          r
        end
      end
    end

    BASE_PATH = '/usr/local/lib/ruby/gems/1.8'
    PATHS = []
    SPECS = Dir.glob("#{BASE_PATH}/specifications/*.gemspec").collect { |specfile| eval(File.read(specfile)) }.sort!
    SPECS.each do |spec|
      spec.require_paths.each {|path| PATHS << "#{BASE_PATH}/gems/#{spec.full_name}/#{path}"}
    end
    
    def self.search_loadpath(file)
      Dir.glob("{#{($LOAD_PATH).join(',')}}/#{file}{.rb,.so}")
    end
    
    def self.search_gempath(file)
      fullname = Dir.glob("{#{(PATHS).join(',')}}/#{file}{.rb,.so}").first
      return false unless fullname
      SPECS.each do |spec|
        if fullname.include?("/#{spec.full_name}/")
          require_gem(spec.name, spec.version.to_s) 
          return true
        end
      end
    end
  end
end

