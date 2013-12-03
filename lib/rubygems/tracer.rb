class Gem::Tracer
  class << self
    attr_accessor :current_tracer

    def span(*desc, &blk)
      current_tracer.span(*desc, &blk)
    end
  end

  def initialize
    @toplevel = Span.new(:top)
    @current = @toplevel
  end

  attr_reader :toplevel

  class Span
    class << self
      def next_id
        @span_id ||= 0
        @span_id += 1
      end
    end

    def initialize desc, parent=nil
      @id = Span.next_id
      @description = desc
      @parent = parent
      @start = nil
      @runtime = nil
      @children = []

      if parent
        @depth = parent.depth + 1
      else
        @depth = 0
      end
    end

    attr_reader :description, :parent, :runtime, :children, :depth

    def start!
      if Gem.configuration.watch_trace
        padding = "  " * @depth
        $stdout.printf "T| %s%03X => %s\n", padding, @id, @description.inspect
      end

      @start = Time.now
    end

    def stop!
      @runtime = Time.now - @start

      if Gem.configuration.watch_trace
        padding = "  " * @depth
        $stdout.printf "T| %s%03X <= %0.2fs\n", padding, @id, @runtime
      end
    end

    def new_child desc
      s = Span.new desc, self
      @children << s
      s
    end
  end

  def span(*desc)
    s = @current.new_child desc
    s.start!
    @current = s

    if block_given?
      begin
        yield s
      ensure
        s.stop!
        @current = s.parent
      end
    else
      s
    end
  end
end

$stdout.sync = true

Gem::Tracer.current_tracer = Gem::Tracer.new
