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

  def arguments
    "GEMNAME       gem to open the webpage for"
  end

  def usage
    "#{program_name} GEMNAME"
  end

  def execute
    @executor.open_page(get_one_optional_argument, options)
  end

end
