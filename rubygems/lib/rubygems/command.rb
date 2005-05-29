require 'rubygems/user_interaction'

module Gem
  class Command
    include UserInteraction
    
    Option = Struct.new(:short, :long, :description, :handler)
    
    attr_reader :command, :options
    attr_accessor :summary, :defaults, :program_name
    
    def initialize(command, summary=nil, defaults={})
      @command = command
      @summary = summary
      @program_name = "gem #{command}"
      @defaults = defaults
      @options = defaults.dup
      @option_list = []
      @parser = nil
    end
    
    def show_help
      parser.program_name = usage
      say parser
    end

    def usage
      "#{program_name}"
    end

    # Override this method to provide details of the arguments a command takes.  It should
    # return a left-justified string, one argument per line.
    def arguments
      ""
    end

    # This is just like the 'arguments' method, except it describes the default options used.
    def defaults_str
      ""
    end

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
    
    def when_invoked(&block)
      @when_invoked = block
    end
    
    def add_option(*args, &handler)
      @option_list << [args, handler]
    end

    def remove_option(name)
      @option_list.reject! { |args, handler| args.any? { |x| x =~ /^#{name}/ } }
    end
    
    def merge_options(new_options)
      @options = @defaults.clone
      new_options.each do |k,v| @options[k] = v end
    end

    def handles?(args)
      begin
        parser.parse!(args.dup)
        return true
      rescue
        return false
      end
    end

    private 

    def command_manager
      Gem::CommandManager.instance
    end

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
      @parser.separator("    #@summary")
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

      def specific_extra_args(cmd)
          @specific_extra_args ||= Hash.new do |h,k|
              h[k] = Array.new
          end

          r = @specific_extra_args[cmd]
          return r
      end

      def add_specific_extra_args(cmd,args)
          # Access @specific_extra_args so that the hash is
          # created for sure.
          #
          specific_extra_args(cmd)

          if args.kind_of? String
              args = args.split(/\s+/)
          end

          @specific_extra_args[cmd] = args
      end

    end

    add_common_option('--source URL', 'Use URL as the remote source for gems') do |value, options|
      require_gem("sources")
      Gem.sources.clear
      Gem.sources << value
    end
    add_common_option('-p', '--[no-]http-proxy [URL]', 'Use HTTP proxy for remote operations') do |value, options|
      options[:http_proxy] = (value == false) ? :no_proxy : value
    end
    add_common_option('-h', '--help', 'Get help on this command') do |value, options|
      options[:help] = true
    end
    # Backtrace and config-file are added so they show up in the help
    # commands.  Both options are actually handled before the other
    # options get parsed.
    add_common_option('--config-file FILE', "Use this config file instead of default") do end
    add_common_option('--backtrace', 'Show stack backtrace on errors') do end
    add_common_option('--debug', 'Turn on Ruby debugging') do end
  end # class
end # module
