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

    def arguments
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
    
    def merge_options(new_options)
      @options = @defaults.clone
      new_options.each do |k,v| @options[k] = v end
    end

    private

    def handle_options(args)
      @options = @defaults.clone
      parser.parse!(args)
      @options[:args] = args
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
      configure_options(@option_list, option_names)
      @parser.separator("")
      @parser.separator("  Common Options:")
      configure_options(Command.common_options, option_names)
      arguments
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
    end

    add_common_option('--config-file FILE', "Use this config file instead of default") do |value, options|
      options[:config_file] = value
    end
    add_common_option('-p', '--[no-]http-proxy [URL]', 'Use HTTP proxy for remote operations') do |value, options|
      options[:http_proxy] = (value == false) ? :no_proxy : value
    end
    add_common_option('-h', '--help', 'Get help on this command') do |value, options|
      options[:help] = true
    end
      
  end # class
end # module
