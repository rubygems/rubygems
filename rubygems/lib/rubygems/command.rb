require 'rubygems/user_interaction'

module Gem
  class Command
    include UserInteraction
    
    Option = Struct.new(:short, :long, :description, :handler)
    
    attr_reader :command
    attr_accessor :summary, :defaults, :program_name
    
    def initialize(command, summary=nil, defaults={})
      @command = command
      @summary = summary
      @program_name = "gem #{command}"
      @defaults = defaults
      @option_list = []
      @parser = nil
    end
    
    def invoke(*args)
      options = handle_options(args)
      need_help = ! (@when_invoked ? @when_invoked.call(options) : execute(options) )
      if need_help
	@parser.program_name = @program_name
	say @parser
      end
    end
    
    def when_invoked(&block)
      @when_invoked = block
    end
    
    def add_option(*args, &handler)
      @option_list << [args, handler]
    end
    
    private

    def handle_options(args)
      options = @defaults.clone
      require 'optparse'
      @parser = OptionParser.new
      option_names = {}
      configure_options(@option_list, option_names, options)
      @parser.separator("")
      @parser.separator("  Common Options:")
      configure_options(Command.common_options, option_names, options)
      begin
	@parser.parse!(args)
	options[:args] = args
      rescue OptionParser::ParseError => err
	alert_error(err.message)
	terminate_interaction!
      end
      options
    end
    
    def configure_options(option_list, option_names, options)
      option_list.each do |args, handler|
	dashes = args.select { |arg| arg =~ /^-/ }
	next if dashes.any? { |arg| option_names[arg] }
	@parser.on(*args) do |value|
	  handler.call(value, options)
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
