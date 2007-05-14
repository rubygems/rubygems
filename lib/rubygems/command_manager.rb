#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'
require 'rubygems/command'
require 'rubygems/user_interaction'
require 'rubygems/gem_commands'
require 'timeout'

module Gem

  ###################################################################
  # Signals that local installation will not proceed, not that it has
  # been tried and failed.  TODO: better name.
  class LocalInstallationError < Gem::Exception; end
  
  ####################################################################
  # Signals that a file permission error is preventing the user from
  # installing in the requested directories.
  class FilePermissionError < Gem::Exception
    def initialize(path)
      super("You don't have write permissions into the #{path} directory.")
    end
  end

  ####################################################################
  # Signals that a remote operation cannot be conducted, probably due
  # to not being connected (or just not finding host).
  #
  # TODO: create a method that tests connection to the preferred gems
  # server.  All code dealing with remote operations will want this.
  # Failure in that method should raise this error.
  class RemoteError < Gem::Exception; end

  ####################################################################
  # The command manager registers and installs all the individual
  # sub-commands supported by the gem command.
  class CommandManager
    include UserInteraction
    include Commands
    
    # Return the authoratative instance of the command manager.
    def self.instance
      @command_manager ||= CommandManager.new
    end
    
    # Register all the subcommands supported by the gem command.
    def initialize
      @commands = {}
      register_command :build
      register_command :cert
      register_command :check
      register_command :contents
      register_command :dependency
      register_command :environment
      register_command :help
      register_command :install
      register_command :outdated
      register_command :pristine
      register_command :query
      register_command :list
      register_command :rdoc
      register_command :search
      register_command :sources
      register_command :specification
      register_command :uninstall
      register_command :unpack
      register_command :cleanup
      register_command :update
    end
    
    # Register the command object.
    def register_command(command_obj)
      @commands[command_obj] = load_and_instantiate(command_obj)
    end
    
    # Return the registered command from the command name.
    def [](command_name)
      @commands[command_name.intern]
    end
    
    # Return a list of all command names (as strings).
    def command_names
      @commands.keys.collect {|key| key.to_s}.sort
    end
    
    # Run the config specificed by +args+.
    def run(args)
      process_args(args)
    rescue StandardError, Timeout::Error => ex
      alert_error "While executing gem ... (#{ex.class})\n    #{ex.to_s}"
      puts ex.backtrace if Gem.configuration.backtrace
      terminate_interaction(1)
    rescue Interrupt
      alert_error "Interrupted"
      terminate_interaction(1)
    end

    def process_args(args)
      args = args.to_str.split(/\s+/) if args.respond_to?(:to_str)
      if args.size == 0
        say Gem::HELP
        terminate_interaction(1)
      end 
      case args[0]
      when '-h', '--help'
        say Gem::HELP
        terminate_interaction(0)
      when '-v', '--version'
        say Gem::RubyGemsPackageVersion
        terminate_interaction(0)
      when /^-/
        alert_error "Invalid option: #{args[0]}.  See 'gem --help'."
        terminate_interaction(1)
      else
        cmd_name = args.shift.downcase
        cmd = find_command(cmd_name)
        cmd.invoke(*args)
      end
    end

    def find_command(cmd_name)
      possibilities = find_command_possibilities(cmd_name)
      if possibilities.size > 1
        raise "Ambiguous command #{cmd_name} matches [#{possibilities.join(', ')}]"
      end
      if possibilities.size < 1
        raise "Unknown command #{cmd_name}"
      end
      self[possibilities.first]
    end

    def find_command_possibilities(cmd_name)
      len = cmd_name.length
      self.command_names.select { |n| cmd_name == n[0,len] }
    end
    
    private
    def load_and_instantiate(command_name)
      command_name = command_name.to_s
      begin
        Gem::Commands.const_get("#{command_name.capitalize}Command").new
      rescue
        require "rubygems/commands/#{command_name}_command"
        retry
      end
    end
  end
end 
