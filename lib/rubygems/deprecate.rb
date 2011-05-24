##
# Provides a single method +deprecate+ to be used to declare when
# something is going away.
#
#     class Legacy
#       def self.klass_method
#         # ...
#       end
#
#       def instance_method
#         # ...
#       end
#
#       extend Deprecate
#       deprecate :instance_method, "X.z", 2011, 4
#
#       class << self
#         extend Deprecate
#         deprecate :klass_method, :none, 2011, 4
#       end
#     end

module Deprecate

  def self.skip # :nodoc:
    @skip ||= false
  end

  def self.skip= v # :nodoc:
    @skip = v
  end

  ##
  # Temporarily turn off warnings. Intended for tests only.

  def skip_during
    Deprecate.skip, original = true, Deprecate.skip
    yield
  ensure
    Deprecate.skip = original
  end

  ##
  # Simple deprecation method that deprecates +name+ by wrapping it up
  # in a dummy method. It warns on each call to the dummy method
  # telling the user of +repl+ (unless +repl+ is :none) and the
  # year/month that it is planned to go away.

  def deprecate name, repl, year, month
    class_eval {
      old = "_deprecated_#{name}"
      alias_method old, name
      define_method name do |*args, &block| # TODO: really works on 1.8.7?
        klass = self.kind_of? Module
        target = klass ? "#{self}." : "#{self.class}#"
        msg = [ "NOTE: #{target}#{name} is deprecated",
                repl == :none ? " with no replacement" : ", use #{repl}",
                ". It will be removed on or after %4d-%02d-01." % [year, month],
                "\n#{target}#{name} called from #{Gem.location_of_caller.join(":")}",
              ]
        # Having "NOTE: Gem::Specification#default_executable= is deprecated with no replacement. It will be removed on or after 2011-10-01."
        # on servers is really useless. My development environment will tell me which gems use deprecated stuff. I would like my tasks
        # run in crontabs to be quiet. Even if a task completes succesfully, I still get an email now, because of all that deprecation
        # cruft.
        warn "#{msg.join}." unless Deprecate.skip ||
                                   (ENV['RUBYGEMS_SUPPRESS_DEPRECATION_WARNINGS'] || '') =~ /(^|,)(#{target}#{name}|\*)(,|$)/
        send old, *args, &block
      end
    }
  end

  module_function :deprecate, :skip_during
end
