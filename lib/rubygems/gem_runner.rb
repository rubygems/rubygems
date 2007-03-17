#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/gem_commands'

module Gem

  ####################################################################
  # Run an instance of the gem program.
  #
  class GemRunner

    def initialize(options={})
      @command_manager_class = options[:command_manager] || Gem::CommandManager
      @config_file_class = options[:config_file] || Gem::ConfigFile
      @doc_manager_class = options[:doc_manager] || Gem::DocManager
    end

    # Run the gem command with the following arguments.
    def run(args)
      do_configuration(args)
      cmd = @command_manager_class.instance
      cmd.command_names.each do |c|
        Command.add_specific_extra_args c, Array(Gem.configuration[c])
      end
      cmd.run(Gem.configuration.args)
    end

    private

    def do_configuration(args)
      Gem.configuration = @config_file_class.new(args)
      Gem.use_paths(Gem.configuration[:gemhome], Gem.configuration[:gempath])
      Command.extra_args = Gem.configuration[:gem]
      @doc_manager_class.configured_args = Gem.configuration[:rdoc]
    end

  end # class
end # module
