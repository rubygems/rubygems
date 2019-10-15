# frozen_string_literal: true
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
#       extend Gem::Deprecate
#       deprecate :instance_method, "X.z", 2011, 4
#
#       class << self
#         extend Gem::Deprecate
#         deprecate :klass_method, :none, 2011, 4
#       end
#     end

module Gem::Deprecate

  def self.skip # :nodoc:
    @skip ||= false
  end

  def self.skip=(v) # :nodoc:
    @skip = v
  end

  ##
  # Temporarily turn off warnings. Intended for tests only.

  def skip_during
    Gem::Deprecate.skip, original = true, Gem::Deprecate.skip
    yield
  ensure
    Gem::Deprecate.skip = original
  end

  ##
  # Simple deprecation method that deprecates +name+ by wrapping it up
  # in a dummy method. It warns on each call to the dummy method
  # telling the user of +repl+ (unless +repl+ is :none) and the
  # year/month that it is planned to go away.

  def deprecate(name, repl, year, month)
    class_eval do
      old = "_deprecated_#{name}"
      alias_method old, name
      define_method name do |*args, &block|
        klass = self.kind_of? Module
        target = klass ? "#{self}." : "#{self.class}#"
        msg = [ "NOTE: #{target}#{name} is deprecated",
                repl == :none ? " with no replacement" : "; use #{repl} instead",
                ". It will be removed on or after %4d-%02d-01." % [year, month],
                "\n#{target}#{name} called from #{Gem.location_of_caller.join(":")}",
        ]
        warn "#{msg.join}." unless Gem::Deprecate.skip
        send old, *args, &block
      end
    end
  end

  # Deprecation method to deprecate Rubygems commands
  def deprecate_command(year, month)
    class_eval do
      # Year we want the command to be deprecated
      @@deprecation_year = year

      # Month we want the command to be deprecated
      @@deprecation_month = month

      # We will be calling the deprecation warning whenever the "execute" method is called
      @@command_method = :execute

      # state variable to avoid infinite loop
      @@command_found = false

      # Original command name where this method is called.
      # e.g if we call this method inside the Gem::Commands::QueryCommand class, this variable will be "query"
      @@command = "#{self}".split("::").last.split(/(?=[A-Z])/).first.downcase

      def self.method_added(method_name)
        # Look only when @@command_method is added/loaded
        if method_name == @@command_method
          # If we don't return early this will be called recursively forerver.
          # method_added will be called everytime we "define_method"
          return if @@command_found

          @@command_found = true

          # Alias "execute" to "_deprecated_execute"
          old = "_deprecated_#{method_name}"
          alias_method old, method_name

          # Overwrite execute method with our custom method that will display the deprecation message
          define_method method_name do |*args, &block|
            send(old, *args, &block)

            # We will call the deprecation warning only on the class in which we are calling "deprecate_command"
            # This is to avoid calling the deprecation warning on classes which inherits from the class we are calling "deprecate_command"

            # Example:
            #
            #class Gem::Commands::QueryCommand
            #    deprecate_command(2019, 12)
            #
            #    def execute
            #      do_something
            #    end
            # end
            #
            # class Gem::Commands::InfoCommand < Gem::Commands::QueryCommand; end

            # This check will prevent the deprecation warning happening when we execute "gem info" and display it
            # only when we call "gem query" as expected
            if "#{self.command}" == @@command
              msg = [ "\nNOTE: #{self.command} command is deprecated",
                      ". It will be removed on or after %4d-%02d-01.\n" % [@@deprecation_year, @@deprecation_month],
              ]

              warn "#{msg.join}" unless Gem::Deprecate.skip
            end
          end
        end
      end
    end
  end

  module_function :deprecate, :deprecate_command, :skip_during

end
