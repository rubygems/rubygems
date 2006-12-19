#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

$:.unshift "lib"
require 'rubygems'

required_version = Gem::Version::Requirement.create(">= 1.8.2")
unless required_version.satisfied_by?(Gem::Version.new(RUBY_VERSION)) then
  abort "Expected Ruby Version #{required_version}, was #{RUBY_VERSION}"
end
