#!/usr/bin/env ruby

require 'yaml'

module Gem
  class ConfigFile
    attr_reader :backtrace, :args

    def initialize(arg_list)
      handle_arguments(arg_list)
      begin
        @hash = open(config_file_name) {|f| YAML.load(f) }
      rescue ArgumentError
        warn "Failed to load #{config_file_name}"
      rescue Errno::ENOENT
        # Ignore missing config file error.
      end
      @hash ||= {}
    end

    def config_file_name
      @config_file_name || Gem.config_file
    end

    def [](key)
      @hash[key.to_s]
    end

    private

    def handle_arguments(arg_list)
      need_cfg_name = false
      @args = []
      arg_list.each do |arg|
	if need_cfg_name
	  @config_file_name = arg
	  need_cfg_name = false
	else
	  case arg
	  when /^--backtrace$/
	    @backtrace = true
          when /^--debug$/
            $DEBUG = true
	  when /^--config-file$/
	    need_cfg_name = true
	  when /^--config-file=(.+)$/
	    @config_file_name = $1
	  else
	    @args << arg
	  end
	end
      end
    end
  end

end
