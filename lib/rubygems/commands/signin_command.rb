# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/authorization_utilities'
require 'rubygems/package'

class Gem::Commands::SigninCommand < Gem::Command
  include Gem::AuthorizationUtilities

  def description # :nodoc:
    <<-EOF
        The signin command executes host sign in for a push server (the default is https://rubygems.org). The host can be provided with the host flag or can be inferred from the provided gem. Host resolution matches the resolution strategy for the push command.
    EOF
  end

  def arguments # :nodoc:
    "GEM        built gem that you would like to use for resolving host. This is the qualified gem name to match the push command. example: pkg/foo-bar-1.0.0.gem"
  end

  def usage # :nodoc:
    "#{program_name} GEM"
  end

  def initialize
    super 'signin', 'Signin to a gem server'

    add_option('--host HOST',
               'Push to another gemcutter-compatible host') do |value, options|
      options[:host] = value
    end
  end

  def execute
    sign_in sign_in_host
  end

  def sign_in_host
    options[:host] || default_host
  end

  def default_host
    gem_data = Gem::Package.new(get_one_gem_name)
    gem_data.spec.metadata['default_gem_server']
  end

end
