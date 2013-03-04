#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/ext/builder'
require 'rubygems/command'
require 'fileutils'
require 'tempfile'

class Gem::Ext::ExtConfBuilder < Gem::Ext::Builder

  def self.hack_for_obsolete_sytle_gems(directory)
    return unless directory and File.identical?(directory, ".")
    mf = Gem.read_binary 'Makefile'
    changed = false
    changed |= mf.gsub!(/^(install-rb-default:)(.*)/) {
      "#$1#{$2.gsub(/(?:^|\s+)\$\(RUBY(?:ARCH|LIB)DIR\)\/\S+(?=\s|$)/, '')}"
    }
    changed |= mf.gsub!(/^(install-so:.*DLLIB.*\n)((?:\t.*\n)+)/) {
      "#$1#{$2.gsub(/.*INSTALL.*DLLIB.*\n/, '')}"
    }
    if changed
      File.open('Makefile', 'wb') {|f| f.print mf}
    end
  end

  def self.build(extension, directory, dest_path, results)
    Tempfile.open %w"siteconf .rb", "." do |siteconf|
      siteconf.puts "require 'rbconfig'"
      siteconf.puts "dest_path = #{dest_path.dump}"
      %w[sitearchdir sitelibdir].each do |dir|
        siteconf.puts "RbConfig::MAKEFILE_CONFIG['#{dir}'] = dest_path"
        siteconf.puts "RbConfig::CONFIG['#{dir}'] = dest_path"
      end

      siteconf.flush

      rubyopt = ENV["RUBYOPT"]

      begin
        ENV["RUBYOPT"] = ["-r#{siteconf.path}", rubyopt].compact.join(' ')
        cmd = [Gem.ruby, File.basename(extension), *Gem::Command.build_args].join ' '

        run cmd, results

        hack_for_obsolete_sytle_gems directory

        make dest_path, results

        results
      ensure
        ENV["RUBYOPT"] = rubyopt
      end
    end
  end

end

