#!/usr/bin/env ruby

module Gem

  class GemRunner

    def run(args)
      do_configuration(args)
      cmd = Gem::CommandManager.instance
      cmd.command_names.each do |c|
          Command.add_specific_extra_args c, Array(@cfg[c])
      end
      cmd.run(@cfg)
    end

    private

    def do_configuration(args)
      @cfg = Gem::ConfigFile.new(args)
      Gem.use_paths(@cfg[:gemhome], @cfg[:gempath])
      Command.extra_args = @cfg[:gem]
      DocManager.configured_args = @cfg[:rdoc]
    end

  end

end
