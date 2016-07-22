# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/authorization_utilities'
require 'rubygems/package'

class Gem::Commands::PushCommand < Gem::Command
  include Gem::LocalRemoteOptions
  include Gem::AuthorizationUtilities

  attr_writer :beta_version, :latest_rubygems_version

  def description # :nodoc:
    <<-EOF
The push command uploads a gem to the push server (the default is
https://rubygems.org) and adds it to the index.

The gem can be removed from the index (but only the index) using the yank
command.  For further discussion see the help for the yank command.
    EOF
  end

  def arguments # :nodoc:
    "GEM       built gem to push up"
  end

  def usage # :nodoc:
    "#{program_name} GEM"
  end

  def initialize
    super 'push', 'Push a gem up to the gem server'

    add_proxy_option
    add_key_option

    add_option('--host HOST',
               'Push to another gemcutter-compatible host') do |value, options|
      options[:host] = value
    end
  end

  def execute
    verify_rubygems_version
    sign_in push_host
    send_gem
  end

  def send_gem
    args = [:post, "api/v1/gems"]

    # Always include host, even if it's nil
    args += [ host, push_host ]

    say "Pushing gem to #{host || Gem.host}..."

    response = rubygems_api_request(*args) do |request|
      request.body = Gem.read_binary get_one_gem_name
      request.add_field "Content-Length", request.body.size
      request.add_field "Content-Type",   "application/octet-stream"
      request.add_field "Authorization",  api_key
    end

    with_response response
  end

  def push_host
    say "@host: #{@host}"
    say "options host: #{options[:host]}"
    say "default host: #{default_host}"
    say "push host: #{allowed_push_host}"
    @host ||= options[:host] || default_host || allowed_push_host
  end

  def default_host
    gem_data.spec.metadata['default_gem_server']
  end

  def allowed_push_host
    gem_data.spec.metadata['allowed_push_host']
  end

  def gem_data
    @gem_data ||= Gem::Package.new(get_one_gem_name)
  end

  def verify_rubygems_version
    if beta_version? then
      alert_error <<-ERROR
        You are using a beta release of RubyGems (#{Gem::VERSION}) which is not
        allowed to push gems.  Please downgrade or upgrade to a release version.

        The latest released RubyGems version is #{latest_rubygems_version}

        You can upgrade or downgrade to the latest release version with:

        gem update --system=#{latest_rubygems_version}
      ERROR
      terminate_interaction 1
    end
  end

  def beta_version?
    @beta_version = Gem.beta_version? if @beta_version.nil?
    @beta_version
  end

  def latest_rubygems_version
    @latest_rubygems_version = Gem.latest_rubygems_version if @latest_rubygems_version.nil?
    @latest_rubygems_version
  end
end

