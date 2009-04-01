require 'rubygems'
require 'gauntlet'

class Gem::Gauntlet < Gauntlet
  
  def run(name)
    warn name
    self.dirty = true

    spec = Gem::Specification.load 'gemspec'
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

