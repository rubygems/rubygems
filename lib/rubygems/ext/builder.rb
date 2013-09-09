#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'thread'

class Gem::Ext::Builder

  ##
  # The builder shells-out to run various commands after changing the
  # directory.  This means multiple installations cannot be allowed to build
  # extensions in parallel as they may change each other's directories leading
  # to broken extensions or failed installations.

  CHDIR_MUTEX = Mutex.new # :nodoc:

  def self.class_name
    name =~ /Ext::(.*)Builder/
    $1.downcase
  end

  def self.make(dest_path, results)
    unless File.exist? 'Makefile' then
      raise Gem::InstallError, "Makefile not found:\n\n#{results.join "\n"}"
    end

    # try to find make program from Ruby configure arguments first
    RbConfig::CONFIG['configure_args'] =~ /with-make-prog\=(\w+)/
    make_program = $1 || ENV['make']
    unless make_program then
      make_program = (/mswin/ =~ RUBY_PLATFORM) ? 'nmake' : 'make'
    end

    destdir = '"DESTDIR=%s"' % ENV['DESTDIR'] if RUBY_VERSION > '2.0'

    ['', 'install'].each do |target|
      # Pass DESTDIR via command line to override what's in MAKEFLAGS
      cmd = [
        make_program,
        destdir,
        target
      ].join(' ').rstrip
      run(cmd, results, "make #{target}".rstrip)
    end
  end

  def self.redirector
    '2>&1'
  end

  def self.run(command, results, command_name = nil)
    results << command
    results << `#{command} #{redirector}`

    unless $?.success? then
      raise Gem::InstallError, "#{command_name || class_name} failed:\n\n#{results.join "\n"}"
    end
  end

end

