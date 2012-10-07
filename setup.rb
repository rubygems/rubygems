#--
# Copyright 2006, 2007 by Chad Fowler, Rich Kilmer, Jim Weirich, Eric Hodel
# and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

if RUBY_VERSION < "1.8.7"
  $stderr.puts "Rubygems now requires Ruby 1.8.7 or later"
  exit 1
end

# Make sure rubygems isn't already loaded.
if ENV['RUBYOPT'] or defined? Gem then
  ENV.delete 'RUBYOPT'

  require 'rbconfig'
  config = defined?(RbConfig) ? RbConfig : Config

  ruby = File.join config::CONFIG['bindir'], config::CONFIG['ruby_install_name']
  ruby << config::CONFIG['EXEEXT']

  cmd = [ruby, 'setup.rb', *ARGV].compact
  cmd[1,0] = "--disable-gems" if RUBY_VERSION > "1.9"

  exec(*cmd)
end

Dir.chdir File.dirname(__FILE__)

$:.unshift 'lib'
require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'

Gem::CommandManager.instance.register_command :setup

args = ARGV.clone
if ENV["GEM_PREV_VER"]
  args = [ '--previous-version', ENV["GEM_PREV_VER"] ] + args
end
args.unshift 'setup'

begin
  Gem::GemRunner.new.run args
rescue Gem::SystemExitException => e
  exit e.exit_code
end

