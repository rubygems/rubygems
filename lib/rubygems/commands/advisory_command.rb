# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/package'
require 'rubygems/local_remote_options'
require 'rubygems/version_option'
require 'rubygems/gemcutter_utilities'

class Gem::Commands::AdvisoryCommand < Gem::Command
  include Gem::VersionOption
  include Gem::GemcutterUtilities

  def initialize
    super 'advisory', 'add advisories to gem versions'

    add_version_option
    add_platform_option
  end

  def arguments # :nodoc:
    "GEM  name of the gem to be marked vulnerable"
  end

  def description # :nodoc:
    <<-EOF
The advisory command allows you to add advisories to a gem version.

An advisory can be any vulnerability in the gem that makes the gem
either unusable or risky to use. The risk can or cannot be a security issue.

    EOF
  end

  def usage # :nodoc:
    "#{program_name} advisory GEM -v VERSION [-p PLATFORM]"
  end

  def execute
    version = get_version_from_requirements(options[:version])
    platform  = get_platform_from_requirements(options)

    if version
      send_advisory(version, platform)
    else
      say "A version argument is required: #{usage}"
      terminate_interaction
    end
  end

  private

  def send_advisory(version, platform)
    gem_name = get_one_gem_name
    alert_warning "Once marked, gem advisories cannot be unmarked for that particular version."
    title = ask "Title:"
    description = ask "Description:"
    url = ask "Url:"
    cve = ask "Cve:"
    ask_yes_no("Are you sure you want to proceed adding the vulnerablility for #{gem_name}-#{version}?",true)
    say "Recording advisory for #{gem_name}-#{version} ..."    
    response = rubygems_api_request(:post, 'api/v1/gems/advisory', host) do |request|
      request.add_field("Authorization",   api_key)

      data = {
        'gem_name' => gem_name,
        'version' => version,
        'url' => url,
        'title' => title,
        'description' => description,
        'cve' => cve,
      }
      data['platform'] = platform if platform

      request.set_form_data data
    end
    say response.body
  end

  def get_version_from_requirements(requirements)
    requirements ? requirements.requirements.first[1].version : nil
  end

  def get_platform_from_requirements(requirements)
    Gem.platforms[1].to_s if requirements.key? :added_platform
  end
end
