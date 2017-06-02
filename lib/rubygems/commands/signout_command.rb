# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/commands/query_command'

class Gem::Commands::SignoutCommand < Gem::Commands::QueryCommand

  def initialize
    super 'signout', 'Signout from all the current sessions.'

    remove_option('--name-matches')
  end

  def description # :nodoc:
    'This `signout` command is used to sign out from all the current sessions to be'\
    'able to signin using different set of credentials.'
  end

  def usage # :nodoc:
    program_name
  end

  def execute
    if Gem.configuration.unset_api_key! then
      $stdout.puts "You have successfully signed out out from 'RubyGems.org'."
    else
      $stdout.puts 'You are not currently signed in.'
    end
  rescue StandardError
    $stderr.puts "File '#{Gem.configuration.credentials_path}' must have readonly permission."\
                 " Please make sure its writeable."
  end

end
