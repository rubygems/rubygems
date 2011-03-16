module Gem
  class PathSupport

    ##
    # The system environment provided. Defaults to ENV.
    attr_reader :env

    ##
    # The default system path for managing Gems.
    attr_reader :home

    ##
    # Array of paths to search for Gems.
    attr_reader :path

    def initialize(env=ENV)
      @env = env

      # ENV the machine environment, is type Object, which is why this works.
      if env.kind_of?(Hash)
        @home = Gem::FileSystem.new(env[:home] || ENV["GEM_HOME"] || Gem.default_dir)
        self.path = env[:path] || ENV["GEM_PATH"]
      else
        @home = Gem::FileSystem.new(env["GEM_HOME"] || Gem.default_dir) 
        self.path = env["GEM_PATH"]
      end
    end

    private

    ##
    # Set the Gem home directory (as reported by Gem.dir).

    def home=(home)
      @home = Gem::FileSystem.new(home)
    end

    ##
    # Set the Gem search path (as reported by Gem.path).

    def path=(gpaths)
      gem_path = []

      gpaths ||= (ENV['GEM_PATH'] || "").empty? ? nil : ENV["GEM_PATH"]

      if gpaths
        if gpaths.kind_of?(Array)
          gem_path = gpaths.dup
        else
          gem_path = gpaths.split(File::PATH_SEPARATOR)
        end

        if File::ALT_SEPARATOR then
          gem_path.map! do |this_path|
            this_path.gsub File::ALT_SEPARATOR, File::SEPARATOR
          end
        end

        gem_path << @home
      else
        gem_path = Gem.default_path + [@home]
        
        if defined?(APPLE_GEM_HOME)
          gem_path << APPLE_GEM_HOME
        end
      end

      @path = gem_path.map { |this_path| Gem::FileSystem.new(this_path) }.uniq
    end
  end

  class FileSystem
    attr_reader :path

    ##
    # Default directories in a gem repository

    DIRECTORIES = %w[cache doc gems specifications] unless defined?(DIRECTORIES)

    def initialize(*paths)
      @path = Path.new(*paths)
    end

    ##
    # Quietly ensure the named Gem directory contains all the proper
    # subdirectories.  If we can't create a directory due to a permission
    # problem, then we will silently continue.

    def ensure_gem_subdirectories
      require 'fileutils'

      DIRECTORIES.each do |name|
        fn = send(name)
        FileUtils.mkdir_p fn rescue nil unless File.exist? fn
      end
    end

    def bin
      path.add 'bin'
    end

    def cache
      path.add 'cache'
    end

    def specifications
      path.add 'specifications'
    end

    def gems
      path.add 'gems'
    end

    def doc
      path.add 'doc'
    end

    def source_cache
      path.add 'source_cache'
    end

    def add(*parts)
      path.add(*parts)
    end

    def to_s
      path.to_s
    end

    alias to_str to_s

    def eql?(fs)
      case fs
      when String
        path.eql?(fs)
      when FileSystem
        path.eql?(fs.path)
      else
        false
      end
    end

    alias == eql?

    def hash
      to_s.hash
    end

    class Path
      def initialize(*paths)
        @path = File.join(paths)
      end

      def readable?
        File.readable?(@path)
      end

      def writable?
        File.writable?(@path)
      end

      def path
        @path.dup
      end

      def to_s
        @path.to_s
      end
      
      alias to_str to_s

      def add(*parts)
        self.class.new(@path, *parts)
      end

      def eql?(other_path)
        to_s.eql?(other_path.to_s)
      end

      alias == eql?

      def hash
        to_s.hash
      end
    end
  end

  FS = FileSystem
end
