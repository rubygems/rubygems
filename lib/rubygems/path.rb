module Gem
  class Path
    def initialize(*paths)
      @path = File.expand_path(File.join(paths))
    end

    def readable?
      File.readable?(@path)
    end

    def writable?
      File.writable?(@path)
    end

    def path
      dup
    end

    def add(*parts)
      self.class.new(@path, *parts)
    end

    alias + add
    alias / add

    def subtract(part)
      self.class.new(@path.sub(part, ''))
    end

    alias - subtract

    def size
      File.size(@path)
    end

    def dirname
      self.class.new(File.dirname(@path))
    end

    def glob(pattern)
      Dir.glob(File.join(@path, pattern)).map { |x| self.class.new(x) }
    end

    def stat
      File.stat(@path)
    end

    def directory?
      File.directory?(@path)
    end

    def to_s
      @path.to_s
    end

    alias to_str to_s

    def =~(regex)
      to_s =~ regex
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
