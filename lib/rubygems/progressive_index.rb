module Gem
  class ProgressiveIndex
    def initialize(specs=[], options={})
      @specs = specs
      @remote_includes = []

      @include_deps = options[:include_deps]
    end

    attr_reader :remote_includes

    RUBY = "ruby"

    def output_spec(s)
      plat = s.platform

      if !plat or plat == RUBY
        h = "#{s.name} #{s.version}"
      else
        h = "#{s.name} #{s.version} #{plat}"
      end

      if @include_deps
        if s.respond_to? :runtime_dependencies
          rt = s.runtime_dependencies
          unless rt.empty?
            d = rt.map { |r| "^#{r.name}|#{r.requirement}" }.join(",")
            h << " runtime_deps=#{d}"
          end
        end

        h
      else
        h
      end
    end

    def output
      if @remote_includes.empty?
        header = ""
      else
        header = @remote_includes.map { |x| "@#{x}" }.join("\n")
      end

      body = @specs.map { |s| output_spec(s) }.join("\n")

      if body.empty?
        if header.empty?
          "\n"
        else
          header + "\n"
        end
      elsif header.empty?
        body + "\n"
      else
        header + "\n" + body + "\n"
      end
    end

    def parse_value(v)
      if m = /^\^(.*)\|(.*)/.match(v)
        Gem::Dependency.new($1, $2)
      else
        v
      end
    end

    def parse_metadata(md)
      out = {}

      md.split(";").each do |l|
        k, v = l.split(":", 2)
        if v.index(",")
          v = v.split(",").map { |a| parse_value(a) }
        else
          v = parse_value(v)
        end

        out[k] = v
      end

      out
    end

    def parse_line(l)
      parts = l.split(" ", 4)
      if parts.size == 4
        parts[3] = parse_metadata(parts[3])
      end

      NameTuple.new(*parts)
    end

    def parse(str)
      ary = str.split("\n")
      if m = /^@(.*)/.match(ary.first)
        @remote_includes << m[1]
        ary.shift
      end

      ary.map { |x| parse_line(x) }
    end
  end
end
