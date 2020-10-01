# frozen_string_literal: true

# `uplevel` keyword argument of Kernel#warn is available since ruby 2.5.
if RUBY_VERSION >= "2.5"

  module Gem::KernelExt
    def warn(*messages, **kw)
      rubygems_path = "#{__dir__}/" # Frames to be skipped start with this path.

      unless uplevel = kw[:uplevel]
        if Gem.java_platform?
          return super(*messages)
        else
          return super(*messages, **kw)
        end
      end

      # Ensure `uplevel` fits a `long`
      uplevel, = [uplevel].pack("l!").unpack("l!")

      if uplevel >= 0
        start = 0
        while uplevel >= 0
          loc, = caller_locations(start, 1)
          unless loc
            # No more backtrace
            start += uplevel
            break
          end

          if path = loc.path
            unless path.start_with?(rubygems_path) or path.start_with?('<internal:')
              # Non-rubygems frames
              uplevel -= 1
              break if uplevel < 0
            end
          end

          start += 1
        end
        kw[:uplevel] = start
      end

      super(*messages, **kw)
    end
  end

  extend Gem::KernelExt
  Kernel.singleton_class.prepend Gem::KernelExt
end
