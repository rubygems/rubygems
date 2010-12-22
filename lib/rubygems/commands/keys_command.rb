require 'rubygems/command'
require 'rubygems/gemcutter_utilities'

class Gem::Commands::KeysCommand < Gem::Command
  include Gem::GemcutterUtilities

  def initialize
    super 'keys', 'Manage API keys for RubyGems.org'

    add_option '-l', '--list', 'List available API keys' do |value,options|
      options[:list] = value
    end

    add_option '-d', '--default KEYNAME',
               'Set the API key to use when none is specified' do |value,options|
      options[:default] = value
    end

    add_option '-r', '--remove KEYNAME',
               'Remove an API key from the list of available keys' do |value,options|
      options[:remove] = value
    end

    add_option '-a', '--add KEYNAME',
               'Add an API key to the list of available keys' do |value,options|

      options[:add] = value
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
      say "Enter your Rubygems.org credentials" # TODO customize with host

      email    =              ask "   Email: "
      password = ask_for_password "Password: "
      say

      response = rubygems_api_request :get, "api/v1/api_key" do |request|
        request.basic_auth email, password
      end

      with_response response do
        added = options[:add].to_sym
        keys = Gem.configuration.api_keys.merge(added => response.body)
        Gem.configuration.api_keys = keys
        say "Added #{added} API key"
      end
    end

    if options[:default] then
      default = options[:default].to_sym

      if Gem.configuration.api_keys.key? default then
        Gem.configuration.rubygems_api_key = Gem.configuration.api_keys[default]
        say "Now using #{default} API key"
      else
        alert_error "No such API key. You can add it with gem keys --add #{default}"
        terminate_interaction 1
      end
    end

    if options[:remove] then
      removed = options[:remove].to_sym

      if Gem.configuration.api_keys.key? removed then
        keys = Gem.configuration.api_keys
        keys.delete removed
        Gem.configuration.api_keys = keys
        say "Removed #{removed} API key"
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
