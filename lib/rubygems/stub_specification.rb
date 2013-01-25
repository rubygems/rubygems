module Gem
  # Gem::StubSpecification reads the stub: line from the gemspec
  # This prevents us having to eval the entire gemspec in order to
  # find out certain information.
  class StubSpecification
    # :nodoc:
    PREFIX = "# stub: "

    # :nodoc:
    class StubLine
      attr_reader :parts

      def initialize(data)
        @parts = data[PREFIX.length..-1].split(" ")
      end

      def name
        @parts[0]
      end

      def version
        Gem::Version.new @parts[1]
      end

      def platform
        @parts[2]
      end

      def require_paths
        @parts[3..-1].join(" ").split("\0")
      end
    end

    ##
    # The filename of the gemspec

    attr_reader :filename

    def initialize(filename)
      @filename = filename
      @data     = nil
      @spec     = nil
    end

    ##
    # Name of the gem

    def name
      data.name
    end

    ##
    # Version of the gem

    def version
      data.version
    end

    ##
    # Platform of the gem

    def platform
      data.platform
    end

    ##
    # Require paths of the gem

    def require_paths
      data.require_paths
    end

    ##
    # The Gem::Specification for this gem

    def spec
      @spec ||= Gem::Specification.load(filename)
    end

    private

    def data
      unless @data
        File.open(filename, "r:UTF-8:-") do |file|
          file.readline # discard encoding line
          stubline = file.readline.chomp
          @data = StubLine.new(stubline) if stubline.start_with?(PREFIX)
        end
      end

      @data ||= spec
    end
  end
end
