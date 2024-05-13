#!/usr/bin/env ruby
# frozen_string_literal: true

#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require "rubygems"

if ARGV.include?("-h") || ARGV.include?("--help")
  warn "rubygems_update [options]"
  warn ""
  warn "This will install the latest version of RubyGems."
  warn ""
  warn "\t--version=X.Y\tUpdate RubyGems from the X.Y version."
  exit
end

unless ARGV.grep(/--version=([\d\.]*)/).empty?
  exec Gem.ruby, "-S", $PROGRAM_NAME, "_#{$1}_"
end

update_dir = $LOAD_PATH.find {|dir| dir.include?("rubygems-update") }

if update_dir.nil?
  puts "Error: Cannot find RubyGems update path!"
  puts
  puts "RubyGems has already been updated."
  puts "The rubygems-update gem may now be uninstalled."
  puts "E.g.    gem uninstall rubygems-update"
else
  update_dir = File.dirname(update_dir)
  Dir.chdir update_dir
  ENV["GEM_PREV_VER"] = Gem::VERSION
  abort unless system(Gem.ruby, "--disable-gems", "setup.rb", *ARGV)
end
