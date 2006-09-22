#!/usr/bin/env ruby

require 'stringio'

module Gem
  module IoCapture
    
    # Return output to $stdout during block execution as a string.
    def capture_stdout
      old_stdout = $stdout
      sio = StringIO.new
      $stdout = sio
      yield
      sio.string
    ensure
      $stdout = old_stdout
    end
    private :capture_stdout
    
    # Return output to $stderr during block execution as a string.
    def capture_stderr
      old_stderr = $stderr
      sio = StringIO.new
      $stderr = sio
      yield
      sio.string
    ensure
      $stderr = old_stderr
    end
    private :capture_stderr
    
  end
end
