require 'yaml'

require 'rubygems/builder'
require 'rubygems/command'
require 'rubygems/command_aids'

class Gem::Commands::BuildCommand < Gem::Command

  include Gem::CommandAids

  def initialize
    super('build', 'Build a gem from a gemspec')
  end

  def usage
    "#{program_name} GEMSPEC_FILE"
  end

  def arguments
    "GEMSPEC_FILE      name of gemspec file used to build the gem"
  end

  def execute
    gemspec = get_one_gem_name
    if File.exist?(gemspec)
      specs = load_gemspecs(gemspec)
      specs.each do |spec|
        Gem::Builder.new(spec).build
      end
    else
      alert_error "Gemspec file not found: #{gemspec}"
    end
  end

  def load_gemspecs(filename)
    if yaml?(filename)
      result = []
      open(filename) do |f|
        begin
          while not f.eof? and spec = Gem::Specification.from_yaml(f)
            result << spec
          end
        rescue Gem::EndOfYAMLException => e
          # OK
        end
      end
    else
      result = [Gem::Specification.load(filename)]
    end
    result
  end

  def yaml?(filename)
    line = open(filename) { |f| line = f.gets }
    result = line =~ %r{^--- *!ruby/object:Gem::Specification}
    result
  end
end
