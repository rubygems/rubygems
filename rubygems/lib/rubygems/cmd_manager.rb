require 'rubygems'
require 'rubygems/command'
require 'rubygems/user_interaction'
require 'rubygems/gem_commands'

module Gem

  # Signals that local installation will not proceed, not that it has been tried and
  # failed.  TODO: better name.
  class LocalInstallationError < StandardError; end

  # Signals that a remote operation cannot be conducted, probably due to not being
  # connected (or just not finding host).
  #
  # TODO: create a method that tests connection to the preferred gems server.  All code
  # dealing with remote operations will want this.  Failure in that method should raise
  # this error.
  class RemoteError < StandardError; end

  class CommandManager
    include UserInteraction

    def self.instance
      @cmd_manager ||= CommandManager.new
    end

    def initialize
      @commands = {}
      register_command HelpCommand.new
      register_command InstallCommand.new
      register_command UninstallCommand.new
      register_command CheckCommand.new
      register_command BuildCommand.new
      register_command QueryCommand.new
      register_command ListCommand.new
      register_command UpdateCommand.new
      register_command EnvironmentCommand.new
      register_command InfoCommand.new
    end
    
    def register_command(command)
      @commands[command.command.intern] = command
    end
    
    def [](command_name)
      @commands[command_name.intern]
    end
    
    def command_names
      @commands.keys.collect {|key| key.to_s}.sort
    end
    
    def run(args)
      process_args(args)
    rescue Gem::Exception => ex
      alert_error "While executing gem ... (#{ex.class})\n    #{ex.to_s}"
      terminate_interaction(1)
    rescue RuntimeError => ex
      alert_error "While executing gem ... (#{ex.class})\n    #{ex.to_s}"
      terminate_interaction(1)
    end

    def process_args(args)
      args = args.to_str.split(/\s/) if args.respond_to?(:to_str)
      if args.size==0
	say Gem::HELP
	terminate_interaction(1)
      elsif args[0]=~/--/
	self['help'].invoke(*args)
      else
        cmd_name = args.shift
        cmd = find_command(cmd_name)
        #load_config_file_options(args)
        cmd.invoke(*args)
      end
    end

    def find_command(cmd_name)
      len = cmd_name.length
      possibilities = self.command_names.select { |n| cmd_name == n[0,len] }
      if possibilities.size > 1
        raise "Ambiguous command #{cmd_name} matches [#{possibilities.join(', ')}]"
      end
      if possibilities.size < 1
        raise "Unknown command #{cmd_name}"
      end
      self[possibilities.first]
    end
    
    #  - a config file may be specified on the command line
    #  - if it's specified multiple times, the first one wins 
    #  - there is a default config file location HOME/.gemrc
    def load_config_file_options(args)
      config_file = File.join(ENV['HOME'], ".gemrc")
      if args.index("--config-file")
        config_file = args[args.index("--config-file")+1]
      end
      if File.exist?(config_file)
        @config_file_options = YAML.load(File.read(config_file))
      else
        alert_error "Config file #{config_file} not found" if options[:config_file]
        terminate_interaction!if options[:config_file]
      end
    end

  end
end 
