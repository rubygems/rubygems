require 'rubygems'

# Available list of platforms for targeting Gem installations.
#
module Gem::Platform

  def self.local
    @local ||= normalize Config::CONFIG['arch']
  end

  def self.match(platform)
    # This data is from http://gems.rubyforge.org/gems/yaml on 19 Aug 2007
    platform = case platform
               when /^i686-darwin(\d)/ then     ['x86',       'darwin',  $1]
               when /^i\d86-linux/ then         ['x86',       'linux',   nil]
               when 'java', 'jruby' then        [nil,         'java',    nil]
               when /mswin32/ then              ['x86',       'mswin32', nil]
               when 'powerpc-darwin' then       ['powerpc',   'darwin',  nil]
               when /powerpc-darwin(\d)/ then   ['powerpc',   'darwin',  $1]
               when /sparc-solaris2.8/ then     ['sparc',     'solaris', '2.8']
               when /universal-darwin(\d)/ then ['universal', 'darwin',  $1]
               else                             platform
               end

    Gem.platforms.any? do |local_platform|
      case platform
      when Array then
        cpu, os, ver = platform
        lcpu, los, lver = local_platform

        # cpu
        (lcpu == 'universal' or cpu == 'universal' or lcpu == cpu) and

        # os
        los == os and

        # ver
        (lver.nil? or ver.nil? or lver == ver)
      when nil then # ruby
        true
      else
        local_platform == platform
      end
    end
  end

  def self.normalize(arch)
    cpu, os = arch.split '-', 2
    cpu, os = nil, cpu if os.nil? # legacy jruby

    cpu = case cpu
          when /i\d86/ then 'x86'
          else cpu
          end

    os = case os
         when /aix(\d+)/ then             [ 'aix',       $1  ]
         when /cygwin/ then               [ 'cygwin',    nil ]
         when /darwin(\d+)?/ then         [ 'darwin',    $1  ]
         when /freebsd(\d+)/ then         [ 'freebsd',   $1  ]
         when /hpux(\d+)/ then            [ 'hpux',      $1  ]
         when /^java$/ then               [ 'java',      nil ]
         when /^java([\d.]*)/ then        [ 'java',      $1  ]
         when /linux/ then                [ 'linux',     $1  ]
         when /mingw32/ then              [ 'mingw32',   nil ]
         when /mswin32/ then              [ 'mswin32',   nil ]
         when /netbsdelf/ then            [ 'netbsdelf', nil ]
         when /openbsd(\d+\.\d+)/ then    [ 'openbsd',   $1  ]
         when /solaris(\d+\.\d+)/ then    [ 'solaris',   $1  ]
         when /^(\w+_platform)(\d+)/ then [ $1,          $2  ] # for testing
         else                             [ 'unknown',   nil ]
         end

    [cpu, os].flatten
  end

  ##
  # A pure-ruby gem that may use Gem::Specification#extensions to build
  # binary files.

  RUBY = 'ruby'

  ##
  # A platform-specific gem that is built for the packaging ruby's platform.
  # This will be replaced with Gem::Platform::local.

  CURRENT = 'current'

  ##
  # A One Click Installer-compatible gem

  MSWIN32 = normalize 'x86-mswin32'

  ##
  # An x86 Linux-compatible gem

  X86_LINUX = normalize 'x86-linux'

  ##
  # A PowerPC Darwin-compatible gem

  PPC_DARWIN = normalize 'powerpc-darwin'

  # :stopdoc:
  # Here lie legacy constants.  These are deprecated.
  WIN32 = 'mswin32'
  LINUX_586 = 'i586-linux'
  DARWIN = 'powerpc-darwin'
  # :startdoc:

end

