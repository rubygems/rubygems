# frozen_string_literal: true

require 'gem/web'

class Gem::Commands::WebCommand < Gem::Command

  include Gem::VersionOption

  def initialize
    super 'web', "Open the gem's homepage",
      :command => nil,
      :version => Gem::Web::VERSION,
      :latest => false

    add_option("-g", "--github", "Open GitHub page of gem, this searches all urls for a GitHub page. This is the default.") do |v|
      options[:github] = v
    end
    add_option("-c", "--sourcecode", "Open sourcecode gem") do |v|
      options[:sourcecode] = v
    end
    add_option("-d", "--doc", "Open documentation of gem") do |v|
      options[:doc] = v
    end
    add_option("-w", "--webpage", "Open webpage of gem") do |v|
      options[:webpage] = v
    end
    add_option("-r", "--rubygems", "Open the rubygems page of a gem") do |v|
      options[:rubygems] = v
    end
    add_option("-t", "--rubytoolbox", "Open the ruby toolbox page of a gem") do |v|
      options[:rubytoolbox] = v
    end
  end

  def arguments
    "GEMNAME       gem to open the webpage for"
  end

  def usage
    "[GEMNAME]"
  end

  def execute
    Gem::Web::Executor.new.open_page(get_one_optional_argument, options)
  end

end
