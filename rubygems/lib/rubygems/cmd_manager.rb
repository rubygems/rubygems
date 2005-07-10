require 'rubygems'
require 'rubygems/command'
require 'rubygems/user_interaction'
require 'rubygems/gem_commands'

module Gem

  # Signals that local installation will not proceed, not that it has
  # been tried and failed.  TODO: better name.
  class LocalInstallationError < Gem::Exception; end
  
  class FilePermissionError < Gem::Exception
    def initialize(path)
      super("You don't have write permissions into the #{path} directory.")
    end
  end

  # Signals that a remote operation cannot be conducted, probably due to not being
  # connected (or just not finding host).
  #
  # TODO: create a method that tests connection to the preferred gems server.  All code
  # dealing with remote operations will want this.  Failure in that method should raise
  # this error.
  class RemoteError < Gem::Exception; end

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
      register_command DependencyCommand.new
      register_command QueryCommand.new
      register_command ListCommand.new
      register_command SearchCommand.new
      register_command UpdateCommand.new
      register_command CleanupCommand.new
      register_command RDocCommand.new
      register_command EnvironmentCommand.new
      register_command SpecificationCommand.new
      register_command UnpackCommand.new
      register_command CertCommand.new
      register_command ContentsCommand.new
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
    
    def run(cfg)
      process_args(cfg.args)
    rescue StandardError => ex
      alert_error "While executing gem ... (#{ex.class})\n    #{ex.to_s}"
      puts ex.backtrace if cfg.backtrace
      terminate_interaction(1)
    end

    def process_args(args)
      args = args.to_str.split(/\s/) if args.respond_to?(:to_str)
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
        #load_config_file_options(args)
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

    #  - a config file may be specified on the command line
    #  - if it's specified multiple times, the first one wins 
    #  - there is a default config file location HOME/.gemrc
    def load_config_file_options(args)
      config_file = Gem.config_file
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
