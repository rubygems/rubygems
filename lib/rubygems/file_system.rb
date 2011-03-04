module Gem
  class FileSystem
    attr_reader :path

    def initialize(path)
      @path = Path.new(path)
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

    class Path
      def initialize(path)
        @path = path
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
      
      alias to_s path
      alias to_str path

      def add(filename)
        self.class.new(@path, filename)
      end
    end
  end
end
