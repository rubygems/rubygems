#!/usr/bin/env ruby

module Gem

  class GemRunner

    def run(args)
      do_configuration(args)
      Gem::CommandManager.instance.run(@cfg)
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
