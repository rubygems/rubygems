#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'fileutils'
require 'rubygems'
require 'test/unit/testsuite'
require 'test/unit/ui/reporter/reporter'
require 'test/unit/ui/console/testrunner'

fail "Missing Test Results Directory" if ARGV.empty?
html_dir = ARGV.shift

FileUtils.rm_r html_dir rescue nil
FileUtils.mkdir_p html_dir

Dir['test/test*.rb'].each do |fn|
  load fn
end

suite = Test::Unit::TestSuite.new
ObjectSpace.each_object(Class) do |cls|
  next if cls == Test::Unit::TestCase
  suite << cls.suite if cls.respond_to?(:suite)
end

Test::Unit::UI::Reporter::Reporter.run(suite, html_dir)
