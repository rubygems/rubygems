#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

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

    # These local versions of Gem::Version and Gem::Specification are
    # used by the load path manager because they are faster than the
    # fully functional ones.  Full functionality is not required
    # during the load phase.
    module Gem
      class Version
        class Requirement
          def initialize(string)
          end
        end
      end
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
            if @platform.nil? || @platform == "ruby" || @platform == ""
              "#{@name}-#{@version}"
            else
              "#{@name}-#{@version}-#{@platform}"
            end
        end
        def method_missing(method, *args)
        end
        def <=>(other)
          r = @name<=>other.name
          r = other.version<=>@version if r == 0
          r
        end
	def to_s
	  "#<Gem::Specification name=#{@name} version=#{@version} quick=true>"
	end
      end
    end

    def self.paths
      @paths
    end

    # Prep the list of potential paths for require file resolution.
    def self.build_paths
      @specs ||= []
      @paths = []
      ::Gem.path.each do |gempath|
        newspecs = Dir.glob("#{gempath}/specifications/*.gemspec").collect { |specfile|
	  eval(File.read(specfile))
	}.sort
        @specs.concat(newspecs)
        newspecs.each do |spec|
          spec.require_paths.each {|path| @paths << "#{gempath}/gems/#{spec.full_name}/#{path}"}
        end
      end
    end
    
    # True if the file can be resolved with the existing load path.
    def self.search_loadpath(file)
      glob_over($LOAD_PATH, file).size > 0
    end
    
    def self.search_gempath(file)
      build_paths unless @paths
      fullname = glob_over(@paths, file).first
      return false unless fullname
      @specs.each do |spec|
        if fullname.include?("/#{spec.full_name}/")
          ::Gem.activate(spec.name, false, spec.version.to_s) 
          return true
        end
      end
      false
    end

    private

    SUFFIX_PATTERN = "{,.rb,.so,.bundle,.dll,.sl}"

    def self.glob_over(list, file)
      files = Dir.glob("{#{(list).join(',')}}/#{file}#{SUFFIX_PATTERN}").map{|x| Marshal.load(Marshal.dump(x))}
      files.delete_if { |f| File.directory?(f) }
    end
    
  end
end

