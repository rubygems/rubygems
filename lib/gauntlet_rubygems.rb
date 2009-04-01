require 'rubygems'
require 'gauntlet'

class GemGauntlet < Gauntlet
  def run(name)
    warn name

    spec = begin
             Gem::Specification.load 'gemspec'
           rescue SyntaxError
             Gem::Specification.from_yaml File.read('gemspec')
           end
    spec.validate

    self.data[name] = false
    self.dirty = true
  rescue SystemCallError, Gem::InvalidSpecificationException => e
    self.data[name] = e.message
    self.dirty = true
  end

  def should_skip?(name)
    self.data[name] == false
  end

  def report
    self.data.sort.reject { |k,v| !v }.each do |k,v|
      puts "%-21s: %s" % [k, v]
    end
  end
end

gauntlet = GemGauntlet.new
gauntlet.run_the_gauntlet ARGV.shift
gauntlet.report
