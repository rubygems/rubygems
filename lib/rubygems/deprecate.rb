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
  
  SKIP_DEFAULT = false
  @skip = nil

  def self.skip # :nodoc:
    @skip.nil? ? SKIP_DEFAULT : @skip
  end

  def self.skip= v # :nodoc:
    @skip = v
  end

  def self.saved_warnings # :nodoc:
    @saved_warnings ||= []
  end
  
  def self.add_warning w  # :nodoc:
    warn "Warning: #{w.message} (Further warnings suppressed until exit.)\n#{w.loc}" if saved_warnings.empty?
    unless saved_warnings.include? w
      @saved_warnings << w
    end
  end

  at_exit do
    # todo: extract and test
    unless Deprecate.saved_warnings.size == 0
      warn Deprecate.report
    end
  end
  
  def self.report
    out = ""
    out << "Some of your installed gems called deprecated methods. See http://blog.zenspider.com/2011/05/rubygems-18-is-coming.html for background. Use 'gem pristine --all' to fix or 'rubygems update --system 1.7.2' to downgrade.\n"
    last_message = nil
    warnings = @saved_warnings.sort_by{|w| w.full_name}.each do |w|
      out << (last_message = w.message) + "\n" unless last_message == w.message
      out << w.loc
      out << "\n"
    end
    out
  end

  ##
  # Temporarily turn off warnings. Intended for tests only.

  def skip_during(will_skip = true)
    Deprecate.skip, original = will_skip, Deprecate.skip
    yield
  ensure
    Deprecate.skip = original
  end

  class Warning
    attr_accessor :target, :method_name, :replacement, :year, :month, :location

    def initialize options
      @target, @method_name, @replacement, @year, @month, @location =
      options[:target], options[:method_name], options[:replacement], options[:year], options[:month], options[:location]
    end
    
    def ==(other)
      target == other.target and
      method_name == other.method_name and
      location == other.location
    end
    
    def message
      [ "#{target}#{method_name} is deprecated",
              replacement == :none ? " with no replacement" : "; use #{replacement} instead.",
              " It will be removed on or after %4d-%02d-01." % [year, month]
      ].join
    end
    
    def loc
      "  called from #{location.join(":")}"
    end
    
    def full_name
      "#{target}#{method_name}"
    end
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
        unless Deprecate.skip
          warning = Warning.new({
            :target => (self.kind_of? Module) ? "#{self}." : "#{self.class}#",
            :method_name => name,
            :location => Gem.location_of_caller,
            :replacement => repl,
            :year => year,
            :month => month
          })
          Deprecate.add_warning warning
        end
        send old, *args, &block
      end
    }
  end

  module_function :deprecate, :skip_during
end
