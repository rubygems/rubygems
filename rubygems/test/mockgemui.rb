#!/usr/bin/env ruby

require 'stringio'
require 'rubygems/user_interaction'

class MockGemUi < Gem::StreamUI
  def initialize(input="")
    super(StringIO.new(input), StringIO.new, StringIO.new)
    @terminated = false
    @banged = false
  end
  
  def input
    @ins.string
  end

  def output
    @outs.string
  end

  def error
    @errs.string
  end

  def banged?
    @banged
  end

  def terminated?
    @terminated
  end

  def terminate_interaction!(status=1)
    @terminated = true
    @banged = true
  end

  def terminate_interaction(status=0)
    @terminated = true
  end
end
