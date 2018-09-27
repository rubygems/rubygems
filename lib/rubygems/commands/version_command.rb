require 'rubygems/command'

class Gem::Commands::VersionCommand < Gem::Command
  def initialize
    super "version", "Print the version of RubyGems"
  end

  def description # :nodoc:
    "Print the version of RubyGems"
  end

  def usage # :nodoc:
    "#{program_name}"
  end

  def execute
    say Gem::VERSION
  end
end
