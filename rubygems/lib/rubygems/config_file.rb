#!/usr/bin/env ruby

require 'yaml'

module Gem
  class ConfigFile
    attr_reader :backtrace, :args

    def initialize(arg_list)
      handle_arguments(arg_list)
      if File.exist?(config_file_name)
	@hash = open(config_file_name) { |f| YAML.load(f) }
      else
	@hash = {}
      end
    end

    def config_file_name
      @config_file_name || default_config_file_name
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

    def default_config_file_name
      File.join(ENV['HOME'], '.gemrc')
    end
  end

end
