require 'rubygems'
require 'rubygems/dependency'
require 'rubygems/dependency_resolver'
require 'rubygems/dependency_list'
require 'rubygems/installer'
require 'tsort'

module Gem
  class RequestSet

    include TSort

    def initialize(*deps)
      @dependencies = deps
      @soft_missing = false

      yield self if block_given?
    end

    # Treat missing dependencies as silent errors
    attr_accessor :soft_missing

    attr_reader :dependencies

    # Declare that a gem of name +name+ with +reqs+ requirements
    # is needed.
    #
    def gem(name, *reqs)
      @dependencies << Gem::Dependency.new(name, reqs)
    end

    # Add +deps+ Gem::Depedency objects to the set.
    #
    def import(deps)
      @dependencies += deps
    end

    # Resolve the requested dependencies and return an Array of
    # Specification objects to be activated.
    #
    def resolve(set=nil)
      r = Gem::DependencyResolver.new(@dependencies, set)
      r.soft_missing = @soft_missing
      @requests = r.resolve
    end

    # Resolve the requested dependencies against the gems
    # available via Gem.path and return an Array of Specification
    # objects to be activated.
    #
    def resolve_current
      resolve DependencyResolver::CurrentSet.new
    end

    # Load a dependency management file.
    #
    def load_gemdeps(path)
      gf = GemDepedencyAPI.new(self, path)
      gf.load
    end

    def specs
      @specs ||= @requests.map { |r| r.full_spec }
    end

    def tsort_each_node(&block)
      @requests.each(&block)
    end

    def tsort_each_child(node)
      node.spec.dependencies.each do |dep|
        next if dep.type == :development

        match = @requests.find { |r| dep.match? r.spec.name, r.spec.version }
        if match
          begin
            yield match
          rescue TSort::Cyclic
          end
        else
          unless @soft_missing
            raise Gem::DependencyError, "Unresolved depedency found during sorting - #{dep}"
          end
        end
      end
    end

    def sorted_requests
      @sorted ||= strongly_connected_components.flatten
    end

    def specs_in(dir)
      Dir["#{dir}/specifications/*.gemspec"].map do |g|
        Gem::Specification.load g
      end
    end

    def install_into dir, force = true, options = {}
      existing = force ? [] : specs_in(dir)

      dir = File.expand_path dir

      installed = []

      sorted_requests.each do |req|
        if existing.find { |s| s.full_name == req.spec.full_name }
          yield req, nil if block_given?
          next
        end

        path = req.download(dir)

        unless path then # already installed
          yield req, nil if block_given?
          next
        end

        options[:install_dir] = dir
        options[:only_install_dir] = true

        inst = Gem::Installer.new path, options

        yield req, inst if block_given?

        inst.install

        installed << req
      end

      installed
    end

    def install options, &block
      if dir = options[:install_dir]
        return install_into dir, false, options, &block
      end

      cache_dir = options[:cache_dir] || Gem.dir

      specs = []

      sorted_requests.each do |req|
        if req.installed?
          yield req, nil if block_given?
          next
        end

        path = req.download cache_dir

        inst = Gem::Installer.new path, options

        yield req, inst if block_given?

        specs << inst.install
      end

      specs
    end

    # A semi-compatible DSL for Bundler's Gemfile format
    #
    class GemDepedencyAPI
      def initialize(set, path)
        @set = set
        @path = path
      end

      def load
        instance_eval File.read(@path).untaint, @path, 1
      end

      # DSL

      def source(url)
      end

      def gem(name, *reqs)
        # Ignore the opts for now.
        reqs.pop if reqs.last.kind_of?(Hash)

        @set.gem name, *reqs
      end

      def platform(what)
        if what == :ruby
          yield
        end
      end

      alias_method :platforms, :platform

      def group(*what)
      end
    end
  end
end
