#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'pp'

def run_tests(pattern='test/test*.rb', log_enabled=false)
  Dir["#{pattern}"].each { |fn|
    puts fn if log_enabled
    begin
      load fn
    rescue Exception => ex
      puts "Error in #{fn}: #{ex.message}"
      puts ex.backtrace
      assert false
    end
  }
end

# You can run the unit tests by running this file directly, providing a pattern.  For example,
#
#   ruby scripts/runtests.rb spec
#
# will load just the "test/test_specification.rb" unit test (unless others match as well).

if $0 == __FILE__
  $:.unshift 'lib'   # Must run this from the root directory.
  pattern = ARGV.shift
  if pattern
    pattern = "test/*#{pattern}*.rb"
    run_tests(pattern, true)
  else
    run_tests
  end
end
