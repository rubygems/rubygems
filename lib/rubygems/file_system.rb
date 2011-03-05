module Gem
  class FileSystem
    attr_reader :path

    def initialize(*paths)
      @path = Path.new(*paths)
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

    def add(obj)
      path.add(obj)
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

      def add(filename)
        self.class.new(File.join @path, filename)
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
