# frozen_string_literal: true

module Gem::Platform::StringParser
  def self.run(arch)
    arch = arch.split "-"

    if arch.length > 2 && arch.last !~ /\d+(\.\d+)?$/ # reassemble x86-linux-{libc}
      extra = arch.pop
      arch.last << "-#{extra}"
    end

    cpu = arch.shift

    parsed_cpu = case cpu
           when /i\d86/ then "x86"
           else cpu
           end

    if arch.length == 2 && arch.last =~ /^\d+(\.\d+)?$/ # for command-line
      parsed_os, parsed_version = arch
      return [parsed_cpu, parsed_os, parsed_version]
    end

    os, = arch
    if os.nil?
      parsed_cpu = nil
      os = cpu
    end # legacy jruby

    parsed_os, parsed_version = case os
                    when /aix(\d+)?/ then             ["aix",       $1]
                    when /cygwin/ then                ["cygwin",    nil]
                    when /darwin(\d+)?/ then          ["darwin",    $1]
                    when /^macruby$/ then             ["macruby",   nil]
                    when /freebsd(\d+)?/ then         ["freebsd",   $1]
                    when /^java$/, /^jruby$/ then     ["java",      nil]
                    when /^java([\d.]*)/ then         ["java",      $1]
                    when /^dalvik(\d+)?$/ then        ["dalvik",    $1]
                    when /^dotnet$/ then              ["dotnet",    nil]
                    when /^dotnet([\d.]*)/ then       ["dotnet",    $1]
                    when /linux-?(\w+)?/ then         ["linux",     $1]
                    when /mingw32/ then               ["mingw32",   nil]
                    when /mingw-?(\w+)?/ then         ["mingw",     $1]
                    when /(mswin\d+)(\_(\d+))?/ then
                      os = $1
                      version = $3
                      parsed_cpu = "x86" if parsed_cpu.nil? && os =~ /32$/
                      [os, version]
                    when /netbsdelf/ then             ["netbsdelf", nil]
                    when /openbsd(\d+\.\d+)?/ then    ["openbsd",   $1]
                    when /solaris(\d+\.\d+)?/ then    ["solaris",   $1]
                    # test
                    when /^(\w+_platform)(\d+)?/ then [$1,          $2]
                    else ["unknown", nil]
                    end

    [parsed_cpu, parsed_os, parsed_version]
  end
end
