#!/usr/bin/env ruby

require 'rubygems'
Gem.manage_gems
require 'rubygems/user_interaction'

include Gem::DefaultUserInteraction

class CaptureSay
  attr_reader :string
  def initialize
    @string = ''
  end
  def say(msg)
    @string << msg << "\n"
  end
end

def pre(cmd, opts)
  puts "<pre>"
  cmd.invoke opts
  puts "</pre>"
end


gm = Gem::CommandManager.instance
hcmd = gm['help']

while line = gets
  if line =~ /^!/
    cmd, arg = line.split
    if cmd == "!usage"
      begin
	cmdobj = gm[arg]
	pre(cmdobj, "--help")
      rescue NoMethodError
	puts "Usage of command #{arg} failed"
      end
    elsif cmd == "!toc"
      cs = CaptureSay.new
      use_ui(cs) do
	gm['help'].invoke 'commands'
      end
      out = cs.string.gsub(/^    (\S+)(.*)$/) {
	'    ' + $1 + $2 +
	  ' [http://rubygems.rubyforge.org/wiki/wiki.pl?GemReference#' +
	  $1 + " goto]"
      }
      out.gsub!(/^/, " ")
      puts out
    elsif cmd == "!version"
      puts Gem::RubyGemsPackageVersion
    end
  else
    puts line
  end
end
