#!/usr/bin/env ruby

##
# gem_server and gem_server.cgi are equivalent programs that allow  
# users to serve gems for consumption by `gem --remote-install`.
# 
# gem_server.cgi specifically serves yaml metadata containing spec 
# information for each installed gem

require 'rubygems'
# OPTION: Change for alternate gem location
gem_path = Gem.dir

print "Content-type:  text/plain\n\n" + Gem::Cache.from_installed_gems(File.join(gem_path, "specifications")).to_yaml
