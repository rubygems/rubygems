module Gem
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
