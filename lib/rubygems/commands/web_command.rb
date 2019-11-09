# frozen_string_literal: true
require 'rubygems/command'
require 'rubygems/executor'

class Gem::Commands::WebCommand < Gem::Command

  def initialize
    super "web", "Open the gem's homepage",
      :command => nil,
      :version => Gem::Requirement.default,
      :latest => false

    add_option("-c", "--sourcecode", "Open source code for the gem") do |v|
      options[:sourcecode] = v
    end
    add_option("-d", "--doc", "Open documentation for the gem") do |v|
      options[:doc] = v
    end
    add_option("-r", "--rubygems", "Open the rubygems.org page for the gem") do |v|
      options[:rubygems] = v
    end

    @executor = Gem::Web::Executor.new
  end

  def arguments # :nodoc:
    "GEMNAME       gem to open the webpage for"
  end

  def usage # :nodoc:
    "#{program_name} GEMNAME"
  end

  def execute
    @executor.open_page(get_one_optional_argument, options)
  end

  def description # :nodoc:
    <<~HEREDOC
      The web command allows you to get/open webpages for a given gem.

      It's possible to configure it to automatically open links:

        $ BROWSER=firefox gem web rails

      If the gem is not hosted on rubygems.org, using --rubygems will result
      in a broken or incorrect link.
    HEREDOC
  end

end
