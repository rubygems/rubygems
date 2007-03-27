#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module Gem
  class DigestAdapter
    def initialize(digest_class)
      @digest_class = digest_class
    end
    def new
      self
    end
    def hexdigest(string)
      @digest_class.new(string).hexdigest
    end
    def digest(string)
      @digest_class.new(string).digest
    end
  end
end