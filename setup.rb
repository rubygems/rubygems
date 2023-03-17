# frozen_string_literal: true

#--
# Copyright 2006, 2007 by Chad Fowler, Rich Kilmer, Jim Weirich, Eric Hodel
# and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

# Make sure rubygems isn't already loaded.
if ENV["RUBYOPT"] || defined? Gem
  ENV.delete "RUBYOPT"

  require "rbconfig"
  cmd = [RbConfig.ruby, "--disable-gems", "setup.rb", *ARGV]

  exec(*cmd)
end

Dir.chdir __dir__

$:.unshift File.expand_path("lib")
require "rubygems"
require "rubygems/gem_runner"

Gem::CommandManager.instance.register_command :setup

args = ARGV.clone
if ENV["GEM_PREV_VER"]
  args = ["--previous-version", ENV["GEM_PREV_VER"]] + args
end
args.unshift "setup"

Gem::GemRunner.new.run args
