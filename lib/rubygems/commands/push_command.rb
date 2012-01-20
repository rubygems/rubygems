require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/gemcutter_utilities'
require 'rubygems/package'

class Gem::Commands::PushCommand < Gem::Command
  include Gem::LocalRemoteOptions
  include Gem::GemcutterUtilities

  def description # :nodoc:
    'Push a gem up to RubyGems.org'
  end

  def arguments # :nodoc:
    "GEM       built gem to push up"
  end

  def usage # :nodoc:
    "#{program_name} GEM"
  end

  def initialize
    super 'push', description
    add_proxy_option
    add_key_option

    add_option('--host HOST',
               'Push to another gemcutter-compatible host') do |value, options|
      options[:host] = value
    end

    add_option('--url URL',
               'Register the gem at URL rather than pushing it') do |v,o|
      o[:url] = v
    end
  end

  def execute
    sign_in
    if u = options[:url]
      send_redirection get_one_gem_name, u
    else
      send_gem get_one_gem_name
    end
  end

  def send_gem name
    args = [:post, "api/v1/gems"]

    if Gem.latest_rubygems_version < Gem::Version.new(Gem::VERSION) then
      alert_error "Using beta/unreleased version of rubygems. Not pushing."
      terminate_interaction 1
    end

    host = options[:host]
    unless host
      if gem_data = Gem::Package.new(name) then
        host = gem_data.spec.metadata['default_gem_server']
      end
    end

    args << host if host

    say "Pushing gem to #{host || Gem.host}..."

    response = rubygems_api_request(*args) do |request|
      request.body = Gem.read_binary name
      request.add_field "Content-Length", request.body.size
      request.add_field "Content-Type",   "application/octet-stream"
      request.add_field "Authorization",  api_key
    end

    with_response response
  end

  def send_redirection path, url
    args = [:post, "api/v1/gems"]

    if Gem.latest_rubygems_version < Gem::Version.new(Gem::VERSION) then
      alert_error "Using beta/unreleased version of rubygems. Not pushing."
      terminate_interaction 1
    end

    gem_data = nil

    host = options[:host]
    unless host
      if gem_data = Gem::Package.new(path) then
        host = gem_data.spec.metadata['default_gem_server']
      end
    end

    args << host if host

    say "Registering gem with #{host || Gem.host}..."

    response = rubygems_api_request(*args) do |request|
      gem_data ||= Gem::Package.new(path)

      request.body = gem_data.spec.to_yaml
      request.add_field "Content-Length", request.body.size
      request.add_field "Content-Type", "application/octet-stream"
      request.add_field "Authorization",  api_key
      request.add_field "Gem-URL", url

      request.add_field "Gem-Hash", Gem::Security.hash_file(path)
    end

    with_response response
  end

end

