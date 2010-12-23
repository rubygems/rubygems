require 'rubygems/command'
require 'rubygems/gemcutter_utilities'
require 'rubygems/local_remote_options'

class Gem::Commands::KeysCommand < Gem::Command
  include Gem::GemcutterUtilities
  include Gem::LocalRemoteOptions

  def initialize
    super 'keys', 'Manage API keys for RubyGems.org'

    add_proxy_option

    add_option '-l', '--list', 'List available API keys' do |value,options|
      options[:list] = value
    end

    add_option '-d', '--default KEYNAME', Symbol,
               'Set the API key to use when none is specified' do |value,options|
      options[:default] = value
    end

    add_option '-r', '--remove KEYNAME', Symbol,
               'Remove an API key from the list of available keys' do |value,options|
      options[:remove] = value
    end

    add_option '-a', '--add KEYNAME', Symbol,
               'Add an API key to the list of available keys' do |value,options|
      options[:add] = value
    end

    add_option '--host HOST', 'Use another gemcutter-compatible host' do |value,options|
      options[:host] = value
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
    options[:list] = !(options[:default] || options[:remove] || options[:add])

    if options[:add] then
      say "Enter your #{URI.parse(options[:host] || Gem.host).host} credentials"

      email    =              ask "   Email: "
      password = ask_for_password "Password: "
      say

      args = [:get, "api/v1/api_key"]
      args << options[:host] if options[:host]

      response = rubygems_api_request(*args) do |request|
        request.basic_auth email, password
      end

      with_response response do
        keys = Gem.configuration.api_keys.merge(options[:add] => response.body)
        Gem.configuration.api_keys = keys
        say "Added #{options[:add]} API key"
      end
    end

    if options[:default] then
      if Gem.configuration.api_keys.key? options[:default] then
        Gem.configuration.rubygems_api_key = Gem.configuration.api_keys[options[:default]]
        say "Now using #{options[:default]} API key"
      else
        alert_error "No such API key. You can add it with gem keys --add #{options[:default]}"
        terminate_interaction 1
      end
    end

    if options[:remove] then
      if Gem.configuration.api_keys.key? options[:remove] then
        keys = Gem.configuration.api_keys
        keys.delete options[:remove]
        Gem.configuration.api_keys = keys
        say "Removed #{options[:remove]} API key"
      else
        say "No such API key"
      end
    end

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
