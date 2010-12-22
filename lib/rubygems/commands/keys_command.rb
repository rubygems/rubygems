require 'rubygems/command'

class Gem::Commands::KeysCommand < Gem::Command

  def initialize
    super 'keys', 'Manage API keys for RubyGems.org'

    add_option '-l', '--list', 'List available API keys' do |value,options|
      options[:list] = value
    end
  end

  def description # :nodoc:
    "Manage API keys on RubyGems.org and compatible gem servers."
  end

  def defaults_str # :nodoc:
    '--list'
  end

  def arguments # :nodoc:
    'KEYNAME       API key to manage'
  end

  def usage # :nodoc:
    "#{program_name} [options] KEYNAME"
  end

  def execute
    options[:list] = true

    if options[:list] then
      api_keys = Gem.configuration.api_keys.sort_by { |k,v| k.to_s }

      say "*** CURRENT KEYS ***"
      say

      api_keys.each do |api_key|
        name, key = api_key
        say " #{Gem.configuration.rubygems_api_key == key ? '*' : ' '} #{name}"
      end
    end
  end
end
