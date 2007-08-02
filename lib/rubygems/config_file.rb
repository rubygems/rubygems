#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'yaml'

require 'rubygems'

module Gem

  ####################################################################
  # Store the gem command options specified in the configuration file.
  # The config file object acts much like a hash.
  #
  class ConfigFile
    
    # List of arguments supplied to the config file object.
    attr_reader :args

    # Verbose level of output:
    # * false -- No output
    # * true -- Normal output
    # * :loud -- Extra output
    attr_accessor :verbose
    
    # Bulk threshhold value.  If the number of missing gems are above
    # this threshhold value, then a bulk download technique is used.
    attr_accessor :bulk_threshhold
    
    # True if we are benchmarking this run.
    attr_accessor :benchmark
    
    # Create the config file object.  +args+ is the list of arguments
    # from the command line.
    #
    # The following command line options are handled early here rather
    # than later at the time most command options are processed.
    #
    # * --config-file and --config-file==NAME -- Obviously these need
    #   to be handled by the ConfigFile object to ensure we get the
    #   right config file.
    #   
    # * --backtrace -- Backtrace needs to be turned on early so that
    #   errors before normal option parsing can be properly handled.
    #
    # * --debug -- Enable Ruby level debug messages.  Handled early
    #   for the same reason as --backtrace.
    #
    def initialize(arg_list)
      @config_file_name = nil

      @backtrace = false
      @benchmark = false
      @bulk_threshhold = 500
      @verbose = true

      handle_arguments(arg_list)

      begin
        @hash = open(config_file_name) {|f| YAML.load(f) }
      rescue ArgumentError
        warn "Failed to load #{config_file_name}"
      rescue Errno::ENOENT
        # Ignore missing config file error.
      rescue Errno::EACCES                 
        warn "Failed to load #{config_file_name} due to permissions problem."
      end

      @hash ||= {}

      # HACK these override command-line args, which is bad
      @backtrace = @hash[:backtrace] if @hash.key? :backtrace
      @benchmark = @hash[:benchmark] if @hash.key? :benchmark
      @bulk_threshhold = @hash[:bulk_threshhold] if @hash.key? :bulk_threshhold
      @verbose = @hash[:verbose] if @hash.key? :verbose
    end

    # True if the backtrace option has been specified, or debug is on.
    def backtrace
      @backtrace or $DEBUG
    end

    # The name of the configuration file.
    def config_file_name
      @config_file_name || Gem.config_file
    end

    # Delegates to @hash
    def each(&block)
      hash = @hash.dup
      hash.delete :verbose
      hash.delete :benchmark
      hash.delete :backtrace
      hash.delete :bulk_threshhold

      yield :verbose, @verbose
      yield :benchmark, @benchmark
      yield :backtrace, @backtrace
      yield :bulk_threshhold, @bulk_threshhold

      yield 'config_file_name', @config_file_name if @config_file_name

      hash.each(&block)
    end

    # Really verbose mode gives you extra output.
    def really_verbose
      case verbose
      when true, false, nil then false
      else true
      end
    end

    # Return the configuration information for +key+.
    def [](key)
      @hash[key.to_s]
    end

    # Set configuration option +key+ to +value+.
    def []=(key, value)
      @hash[key] = value
    end

    private

    # Handle the command arguments.
    def handle_arguments(arg_list)
      need_cfg_name = false
      @args = []
      arg_list.each do |arg|
        if need_cfg_name
          @config_file_name = arg
          need_cfg_name = false
        else
          case arg
          when /^--(traceback|backtrace)$/
            @backtrace = true
          when /^--debug$/
            $DEBUG = true
          when /^--config-file$/
            need_cfg_name = true
          when /^--config-file=(.+)$/
            @config_file_name = $1
          when /^--bench(mark)?$/
            @benchmark = true
          else
            @args << arg
          end
        end
      end
    end
  end

end
