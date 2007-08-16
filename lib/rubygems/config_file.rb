#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'yaml'
require 'rubygems'

# Store the gem command options specified in the configuration file.  The
# config file object acts much like a hash.

class Gem::ConfigFile

  DEFAULT_BACKTRACE = false
  DEFAULT_BENCHMARK = false
  DEFAULT_BULK_THRESHOLD = 500
  DEFAULT_VERBOSITY = true

  # List of arguments supplied to the config file object.
  attr_reader :args

  # True if we print backtraces on errors.
  attr_writer :backtrace

  # True if we are benchmarking this run.
  attr_accessor :benchmark

  # Bulk threshhold value.  If the number of missing gems are above
  # this threshhold value, then a bulk download technique is used.
  attr_accessor :bulk_threshhold

  # Verbose level of output:
  # * false -- No output
  # * true -- Normal output
  # * :loud -- Extra output
  attr_accessor :verbose

  # Create the config file object.  +args+ is the list of arguments
  # from the command line.
  #
  # The following command line options are handled early here rather
  # than later at the time most command options are processed.
  #
  # * --config-file and --config-file==NAME -- Obviously these need
  #   to be handled by the ConfigFile object to ensure we get the
  #   right config file.
  #
  # * --backtrace -- Backtrace needs to be turned on early so that
  #   errors before normal option parsing can be properly handled.
  #
  # * --debug -- Enable Ruby level debug messages.  Handled early
  #   for the same reason as --backtrace.
  #
  def initialize(arg_list)
    @config_file_name = nil
    need_config_file_name = false

    arg_list = arg_list.map do |arg|
      if need_config_file_name then
        @config_file_name = arg
        nil
      elsif arg =~ /^--config-file=(.*)/ then
        @config_file_name = $1
        nil
      elsif arg =~ /^--config-file$/ then
        need_config_file_name = true
        nil
      else
        arg
      end
    end.compact

    @backtrace = DEFAULT_BACKTRACE
    @benchmark = DEFAULT_BENCHMARK
    @bulk_threshhold = DEFAULT_BULK_THRESHOLD
    @verbose = DEFAULT_VERBOSITY

    begin
      # HACK $SAFE ok?
      @hash = open(config_file_name.dup.untaint) {|f| YAML.load(f) }
    rescue ArgumentError
      warn "Failed to load #{config_file_name}"
    rescue Errno::ENOENT
      # Ignore missing config file error.
    rescue Errno::EACCES
      warn "Failed to load #{config_file_name} due to permissions problem."
    end

    @hash ||= {}

    # HACK these override command-line args, which is bad
    @backtrace = @hash[:backtrace] if @hash.key? :backtrace
    @benchmark = @hash[:benchmark] if @hash.key? :benchmark
    @bulk_threshhold = @hash[:bulk_threshhold] if @hash.key? :bulk_threshhold
    Gem.sources.replace @hash[:sources] if @hash.key? :sources
    @verbose = @hash[:verbose] if @hash.key? :verbose

    handle_arguments arg_list
  end

  # True if the backtrace option has been specified, or debug is on.
  def backtrace
    @backtrace or $DEBUG
  end

  # The name of the configuration file.
  def config_file_name
    @config_file_name || Gem.config_file
  end

  # Delegates to @hash
  def each(&block)
    hash = @hash.dup
    hash.delete :verbose
    hash.delete :benchmark
    hash.delete :backtrace
    hash.delete :bulk_threshhold

    yield :verbose, @verbose
    yield :benchmark, @benchmark
    yield :backtrace, @backtrace
    yield :bulk_threshhold, @bulk_threshhold

    yield 'config_file_name', @config_file_name if @config_file_name

    hash.each(&block)
  end

  # Really verbose mode gives you extra output.
  def really_verbose
    case verbose
    when true, false, nil then false
    else true
    end
  end

  # to_yaml only overwrites things you can't override on the command line.
  def to_yaml # :nodoc:
    yaml_hash = {
      :backtrace => @hash[:backtrace] || DEFAULT_BACKTRACE,
      :benchmark => @hash[:benchmark] || DEFAULT_BENCHMARK,
      :bulk_threshhold => @hash[:bulk_threshhold] || DEFAULT_BULK_THRESHOLD,
      :sources => Gem.sources,
      :verbose => @hash[:verbose] || DEFAULT_VERBOSITY,
    }

    @hash.each do |key, value|
      key = key.to_s
      next if key =~ /backtrace|benchmark|bulk_threshhold|verbose|sources|debug/
      yaml_hash[key.to_s] = value
    end

    yaml_hash.to_yaml
  end

  # Writes out this config file, replacing its source.
  def write
    File.open config_file_name, 'w' do |fp|
      fp.write self.to_yaml
    end
  end

  # Return the configuration information for +key+.
  def [](key)
    @hash[key.to_s]
  end

  # Set configuration option +key+ to +value+.
  def []=(key, value)
    @hash[key.to_s] = value
  end

  def ==(other) # :nodoc:
    self.class === other and
    @backtrace == other.backtrace and
    @benchmark == other.benchmark and
    @bulk_threshhold == other.bulk_threshhold and
    @verbose == other.verbose and
    @hash == other.hash
  end

  protected

  attr_reader :hash

  private

  # Handle the command arguments.
  def handle_arguments(arg_list)
    @args = []

    arg_list.each do |arg|
      case arg
      when /^--(backtrace|traceback)$/ then
        @backtrace = true
      when /^--bench(mark)?$/ then
        @benchmark = true
      when /^--debug$/ then
        $DEBUG = true
      else
        @args << arg
      end
    end
  end

end

