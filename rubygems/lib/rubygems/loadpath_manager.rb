module Kernel
  alias require__ require
  def require(file)
    Gem::LoadPathManager.search_loadpath(file) || Gem::LoadPathManager.search_gempath(file)
    require__(file)
  end
end

module Gem
  module LoadPathManager
    @paths = nil
    module Gem
      class Specification
        def initialize(&block)
          @require_paths = ['lib']
          @platform = nil
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
          @full_name ||=
            if @platform == "ruby"
              "#{@name}-#{@version}"
            else
              "#{@name}-#{@version}-#{platform}"
            end
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
    
    def self.build_paths
      @paths = []
      ::Gem.path.each do |gempath|
        @specs = Dir.glob("#{gempath}/specifications/*.gemspec").collect { |specfile| eval(File.read(specfile)) }.sort!
        @specs.each do |spec|
          spec.require_paths.each {|path| @paths << "#{gempath}/gems/#{spec.full_name}/#{path}"}
        end
      end
    end
    
    def self.search_loadpath(file)
      result = Dir.glob("{#{($LOAD_PATH).join(',')}}/#{file}{,.rb,.so}").delete_if {|f| File.directory?(f)}.size > 0
      result
    end
    
    def self.search_gempath(file)
      build_paths unless @paths
      fullname = Dir.glob("{#{(@paths).join(',')}}/#{file}{,.rb,.so}").delete_if {|f| File.directory?(f)}.first
      return false unless fullname
      @specs.each do |spec|
        if fullname.include?("/#{spec.full_name}/")
          ::Gem.activate(spec.name, false, spec.version.to_s) 
          return true
        end
      end
      false
    end
  end
end

