# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/commands/query_command'
require 'rubygems/config_file'
require 'rubygems/gemcutter_utilities'

class Gem::Commands::SigninCommand < Gem::Commands::QueryCommand
  include Gem::GemcutterUtilities

  def initialize
    super 'signin', 'Sign in to any gemcutter-compatible host. '\
          'It defaults to https://rubygems.org'

    remove_option('--name-matches')

    add_option('--host HOST', 'Push to another gemcutter-compatible host') do |value, options|
       options[:host] = value
    end

  end

  def description # :nodoc:
    'The signin command executes host sign in for a push server (the default is'\
    ' https://rubygems.org). The host can be provided with the host flag or can'\
    ' be inferred from the provided gem. Host resolution matches the resolution'\
    ' strategy for the push command.'
  end

  def usage # :nodoc:
    program_name
  end

  def execute
    if File.exist?(Gem.configuration.credentials_path) then
      alert_error 'You are already logged in. If you wish to login using different'\
                  ' credentials or host, then using `signout` command try again.'
    else
      sign_in options[:host]
    end
  end

end
