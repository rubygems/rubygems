#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'
require 'rubygems/command'

module Gem

  class CommandLineError < Gem::Exception; end
  module Commands; end # This is where Commands will be placed in the namespace

  ####################################################################
  # The following mixin methods aid in the retrieving of information
  # from the command line.
  #
  module CommandAids

    # Get the single gem name from the command line.  Fail if there is
    # no gem name or if there is more than one gem name given.
    def get_one_gem_name
      args = options[:args]
      if args.nil? or args.empty?
        fail Gem::CommandLineError,
          "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
      end
      if args.size > 1
        fail Gem::CommandLineError,
          "Too many gem names (#{args.join(', ')}); please specify only one"
      end
      args.first
    end

    # Get all gem names from the command line.
    def get_all_gem_names
      args = options[:args]
      if args.nil? or args.empty?
        raise Gem::CommandLineError,
              "Please specify at least one gem name (e.g. gem build GEMNAME)"
      end
      gem_names = args.select { |arg| arg !~ /^-/ }
    end

    # Get a single optional argument from the command line.  If more
    # than one argument is given, return only the first. Return nil if
    # none are given.
    def get_one_optional_argument
      args = options[:args] || []
      args.first
    end

    # True if +long+ begins with the characters from +short+.
    def begins?(long, short)
      return false if short.nil?
      long[0, short.length] == short
    end
  end

  ####################################################################
  # Mixin methods for handling the local/remote command line options.
  #
  module LocalRemoteOptions

    # Add the local/remote options to the command line parser.
    def add_local_remote_options
      add_option('-l', '--local',
                 'Restrict operations to the LOCAL domain'
                 ) do |value, options|
        options[:domain] = :local
      end

      add_option('-r', '--remote',
        'Restrict operations to the REMOTE domain') do
        |value, options|
        options[:domain] = :remote
      end

      add_option('-b', '--both',
        'Allow LOCAL and REMOTE operations') do
        |value, options|
        options[:domain] = :both
      end
    end

    # Is local fetching enabled?
    def local?
      options[:domain] == :local || options[:domain] == :both
    end

    # Is remote fetching enabled?
    def remote?
      options[:domain] == :remote || options[:domain] == :both
    end
  end

  ####################################################################
  # Mixin methods and OptionParser options specific to the gem install
  # command.
  #
  module InstallUpdateOptions

    # Add the install/update options to the option parser.
    def add_install_update_options
      add_option('-i', '--install-dir DIR',
                 'Gem repository directory to get installed',
                 'gems.') do |value, options|
        options[:install_dir] = File.expand_path(value)
      end

      add_option('-d', '--[no-]rdoc', 
                 'Generate RDoc documentation for the gem on',
                 'install') do |value, options|
        options[:generate_rdoc] = value
      end

      add_option('--[no-]ri', 
                 'Generate RI documentation for the gem on',
                 'install') do |value, options|
        options[:generate_ri] = value
      end

      add_option('-E', '--env-shebang',
                 "Rewrite the shebang line on installed",
                 "scripts to use /usr/bin/env") do |value, options|
        options[:env_shebang] = value
      end

      add_option('-f', '--[no-]force', 
                 'Force gem to install, bypassing dependency',
                 'checks') do |value, options|
        options[:force] = value
      end

      add_option('-t', '--[no-]test', 
        'Run unit tests prior to installation') do 
        |value, options|
        options[:test] = value
      end

      add_option('-w', '--[no-]wrappers', 
        'Use bin wrappers for executables',
        'Not available on dosish platforms') do 
        |value, options|
        options[:wrappers] = value
      end

      add_option('-P', '--trust-policy POLICY', 
        'Specify gem trust policy.') do 
        |value, options|
        options[:security_policy] = value
      end

      add_option('--ignore-dependencies',
        'Do not install any required dependent gems') do 
        |value, options|
        options[:ignore_dependencies] = value
      end

      add_option('-y', '--include-dependencies',
                 'Unconditionally install the required',
                 'dependent gems') do |value, options|
        options[:include_dependencies] = value
      end
    end
    
    # Default options for the gem install command.
    def install_update_defaults_str
      '--rdoc --no-force --no-test --wrappers'
    end
  end

  ####################################################################
  # Mixin methods for the version command.
  #
  module VersionOption

    # Add the options to the option parser.
    def add_version_option(taskname, *wrap)
      add_option('-v', '--version VERSION', 
                 "Specify version of gem to #{taskname}", *wrap) do 
                   |value, options|
        options[:version] = value
      end
    end

  end
  def self.load_commands(*command_names)
    command_names.each{|name| 
      require "rubygems/commands/#{name}_command"
    }
  end
end

######################################################################
# Documentation Constants
#
module Gem

  HELP = %{
    RubyGems is a sophisticated package manager for Ruby.  This is a
    basic help message containing pointers to more information.

      Usage:
        gem -h/--help
        gem -v/--version
        gem command [arguments...] [options...]

      Examples:
        gem install rake
        gem list --local
        gem build package.gemspec
        gem help install

      Further help:
        gem help commands            list all 'gem' commands
        gem help examples            show some examples of usage
        gem help <COMMAND>           show help on COMMAND
                                       (e.g. 'gem help install')
      Further information:
        http://rubygems.rubyforge.org
    }.gsub(/^    /, "")

  EXAMPLES = %{
    Some examples of 'gem' usage.

    * Install 'rake', either from local directory or remote server:
    
        gem install rake

    * Install 'rake', only from remote server:

        gem install rake --remote

    * Install 'rake' from remote server, and run unit tests,
      and generate RDocs:

        gem install --remote rake --test --rdoc --ri

    * Install 'rake', but only version 0.3.1, even if dependencies
      are not met, and into a specific directory:

        gem install rake --version 0.3.1 --force --install-dir $HOME/.gems

    * List local gems whose name begins with 'D':

        gem list D

    * List local and remote gems whose name contains 'log':

        gem search log --both

    * List only remote gems whose name contains 'log':

        gem search log --remote

    * Uninstall 'rake':

        gem uninstall rake
    
    * Create a gem:

        See http://rubygems.rubyforge.org/wiki/wiki.pl?CreateAGemInTenMinutes

    * See information about RubyGems:
    
        gem environment

    }.gsub(/^    /, "")
    
end
