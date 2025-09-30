# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/package'
require 'rubygems/local_remote_options'
require 'rubygems/version_option'
require 'rubygems/gemcutter_utilities'
require 'rubygems/advisory_option'

class Gem::Commands::AuditCommand < Gem::Command
  include Gem::VersionOption
  include Gem::GemcutterUtilities
  include Gem::AdvisoryOption

  def initialize
    super 'audit', 'check if advisories are present'

    add_version_option
    add_platform_option
    add_ignore_cve_option
  end

  def arguments # :nodoc:
    "GEM  name of the gem to be checked for vulnerabilities"
  end

  def description # :nodoc:
    <<-EOF
The audit command allows you to check advisories reported for a gem version.

An advisory can be any vulnerability in the gem that makes the gem
either unusable or risky to use. The risk can or cannot be a security issue.

    EOF
  end

  def usage # :nodoc:
    "#{program_name} GEM -v VERSION [-p PLATFORM]"
  end

  def execute
    version = get_version_from_requirements(options[:version])
    platform  = get_platform_from_requirements(options)
    
    if version then
      check_version(version, platform)
    else
      say "A version argument is required: #{usage}"
      terminate_interaction
    end
  end

  private

  def check_version(version, platform)
    require 'json'

    gem_name = get_one_gem_name

    response = rubygems_api_request(:get, 'api/v1/gems/audit', host) do |request|

      data = {
        'gem_name' => gem_name
      }
      data['version'] = version if version
      data['platform'] = platform if platform

      request.set_form_data data  
    end
    advisories_hash = JSON.parse(response.body)
    advisories_hash.each do |version, details|
      if details['vulnerable']
        details['advisories'].each do |advisory|
          unless advisory[3] == options[:ignore_cve]
            say "Title: #{advisory[0]}"
            say "URL : #{advisory[2]}"
            say "CVE: #{advisory[3]}"
            say "\n"
          end
        end
      else
        say details['advisories']
      end
    end
  end

  def get_version_from_requirements(requirements)
    requirements ? requirements.requirements.first[1].version : nil
  end

  def get_platform_from_requirements(requirements)
    Gem.platforms[1].to_s if requirements.key? :added_platform
  end
end
