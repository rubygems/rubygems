#!/usr/bin/env ruby

module Gem

  class GemRunner

    def run(args)
      cfg = Gem::ConfigFile.new(args)
      Gem.use_paths(cfg[:gemhome], cfg[:gempath])
      Gem::CommandManager.instance.run(cfg.args)
    end

  end

end
