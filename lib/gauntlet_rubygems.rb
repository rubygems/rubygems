require 'rubygems'
require 'gauntlet'

class Gem::Gauntlet < Gauntlet
  
  def run(name)
    warn name
    self.dirty = true

    spec = begin
             Gem::Specification.load 'gemspec'
           rescue SyntaxError
             Gem::Specification.from_yaml 'gemspec'
           end
    spec.validate

    self.data[name] = false

  rescue Gem::InvalidSpecificationException => e
    self.data[name] = e.message
  end

  def should_skip?(name)
    self.data[name] == false
  end

end

gauntlet = Gem::Gauntlet.new
gauntlet.run_the_gauntlet ARGV.shift

