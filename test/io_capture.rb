#!/usr/bin/env ruby

module Gem
  module IoCapture
    
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
    
    def capture_stderr
      require 'stringio'
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
