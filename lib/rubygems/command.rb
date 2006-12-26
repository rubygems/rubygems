#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/user_interaction'

module Gem

  ####################################################################
  # Base class for all Gem commands.
  class Command
    include UserInteraction
    
    Option = Struct.new(:short, :long, :description, :handler)
    
    attr_reader :command, :options
    attr_accessor :summary, :defaults, :program_name
    
    # Initialize a generic gem command.
    def initialize(command, summary=nil, defaults={})
      @command = command
      @summary = summary
      @program_name = "gem #{command}"
      @defaults = defaults
      @options = defaults.dup
      @option_list = []
      @parser = nil
      @when_invoked = nil
    end
    
    # Override to provide command handling.
    def execute
      fail "Generic command has no actions"
    end

    # Override to display the usage for an individual gem command.
    def usage
      program_name
    end

    # Override to provide details of the arguments a command takes.
    # It should return a left-justified string, one argument per line.
    def arguments
      ""
    end

    # Override to display the default values of the command
    # options. (similar to +arguments+, but displays the default
    # values).
    def defaults_str
      ""
    end

    # Display the help message for this command.
    def show_help
      parser.program_name = usage
      say parser
    end

    # Invoke the command with the given list of arguments.
    def invoke(*args)
      handle_options(args)
      if options[:help]
        show_help
      elsif @when_invoked
        @when_invoked.call(options)
      else
        execute
      end
    end
    
    # Call the given block when invoked.
    #
    # Normal command invocations just executes the +execute+ method of
    # the command.  Specifying an invocation block allows the test
    # methods to override the normal action of a command to determine
    # that it has been invoked correctly.
    def when_invoked(&block)
      @when_invoked = block
    end
    
    # Add a option (and a handler) to this command.
    def add_option(*args, &handler)
      @option_list << [args, handler]
    end

    # Remove a previously defined command option.
    def remove_option(name)
      @option_list.reject! { |args, handler| args.any? { |x| x =~ /^#{name}/ } }
    end
    
    # Merge a set of command options with the set of default options
    # (without modifying the default option hash).
    def merge_options(new_options)
      @options = @defaults.clone
      new_options.each do |k,v| @options[k] = v end
    end

    # True if the command handles the given argument list.
    def handles?(args)
      begin
        parser.parse!(args.dup)
        return true
      rescue
        return false
      end
    end

    private 

    # Return the command manager instance.
    def command_manager
      Gem::CommandManager.instance
    end

    # Handle the given list of arguments by parsing them and recording
    # the results.
    def handle_options(args)
      args = add_extra_args(args)
      @options = @defaults.clone
      parser.parse!(args)
      @options[:args] = args
    end
    
    def add_extra_args(args)
      result = []
      s_extra = Command.specific_extra_args(@command)
      extra = Command.extra_args + s_extra
      while ! extra.empty?
        ex = []
        ex << extra.shift
        ex << extra.shift if extra.first.to_s =~ /^[^-]/
        result << ex if handles?(ex)
      end
      result.flatten!
      result.concat(args)
      result
    end
    
    # Create on demand parser.
    def parser
      create_option_parser if @parser.nil?
      @parser
    end

    def create_option_parser
      require 'optparse'
      @parser = OptionParser.new
      option_names = {}
      @parser.separator("")
      unless @option_list.empty?
        @parser.separator("  Options:")
        configure_options(@option_list, option_names)
        @parser.separator("")
      end
      @parser.separator("  Common Options:")
      configure_options(Command.common_options, option_names)
      @parser.separator("")
      unless arguments.empty?
        @parser.separator("  Arguments:")
        arguments.split(/\n/).each do |arg_desc|
          @parser.separator("    #{arg_desc}")
        end
        @parser.separator("")
      end
      @parser.separator("  Summary:")
      wrap(@summary, 80 - 4).each do |line|
        @parser.separator("    #{line.strip}")
      end
      unless defaults_str.empty?
        @parser.separator("")
        @parser.separator("  Defaults:")
        defaults_str.split(/\n/).each do |line|
          @parser.separator("    #{line}")
        end
      end
    end

    def configure_options(option_list, option_names)
      option_list.each do |args, handler|
        dashes = args.select { |arg| arg =~ /^-/ }
        next if dashes.any? { |arg| option_names[arg] }
        @parser.on(*args) do |value|
          handler.call(value, @options)
        end
        dashes.each do |arg| option_names[arg] = true end
      end
    end

    # Wraps +text+ to +width+
    def wrap(text, width)
      text.gsub(/(.{1,#{width}})( +|$\n?)|(.{1,#{width}})/, "\\1\\3\n")
    end

    ##################################################################
    # Class methods for Command.
    class << self
      def common_options
        @common_options ||= []
      end
    
      def add_common_option(*args, &handler)
        Gem::Command.common_options << [args, handler]
      end

      def extra_args
        @extra_args ||= []
      end

      def extra_args=(value)
        case value
        when Array
          @extra_args = value
        when String
          @extra_args = value.split
        end
      end

      # Return an array of extra arguments for the command.  The extra
      # arguments come from the gem configuration file read at program
      # startup.
      def specific_extra_args(cmd)
        specific_extra_args_hash[cmd]
      end
      
      # Add a list of extra arguments for the given command.  +args+
      # may be an array or a string to be split on white space.
      def add_specific_extra_args(cmd,args)
        args = args.split(/\s+/) if args.kind_of? String
        specific_extra_args_hash[cmd] = args
      end

      # Accessor for the specific extra args hash (self initializing).
      def specific_extra_args_hash
        @specific_extra_args_hash ||= Hash.new do |h,k|
          h[k] = Array.new
        end
      end
    end

    # ----------------------------------------------------------------
    # Add the options common to all commands.
    
    add_common_option('--source URL', 
      'Use URL as the remote source for gems') do
      |value, options|
      gem("sources")
      Gem.sources.clear
      Gem.sources << value
    end

    add_common_option('-p', '--[no-]http-proxy [URL]',
      'Use HTTP proxy for remote operations') do 
      |value, options|
      options[:http_proxy] = (value == false) ? :no_proxy : value
      Gem.configuration[:http_proxy] = options[:http_proxy]
    end

    add_common_option('-h', '--help', 
      'Get help on this command') do
      |value, options|
      options[:help] = true
    end

    add_common_option('-v', '--verbose', 
      'Set the verbose level of output') do
      |value, options|
      Gem.configuration.verbose = value
    end

    # Backtrace and config-file are added so they show up in the help
    # commands.  Both options are actually handled before the other
    # options get parsed.

    add_common_option('--config-file FILE', 
      "Use this config file instead of default") do
    end

    add_common_option('--backtrace', 
      'Show stack backtrace on errors') do
    end

    add_common_option('--debug',
      'Turn on Ruby debugging') do
    end
  end # class
end # module
