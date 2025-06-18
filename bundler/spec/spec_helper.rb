# frozen_string_literal: true

require "psych"
require "bundler/vendored_fileutils"
require "bundler/vendored_uri"
require "digest"

if File.expand_path(__FILE__) =~ %r{([^\w/\.:\-])}
  abort "The bundler specs cannot be run from a path that contains special characters (particularly #{$1.inspect})"
end

# Bundler CLI will have different help text depending on whether any of these
# variables is set, since the `-e` flag `bundle gem` with require an explicit
# value if they are not set, but will use their value by default if set. So make
# sure they are `nil` before loading bundler to get a consistent help text,
# since some tests rely on that.
ENV["EDITOR"] = nil
ENV["VISUAL"] = nil
ENV["BUNDLER_EDITOR"] = nil
require "bundler"

require "rspec/core"
require "rspec/expectations"
require "rspec/mocks"
require "rspec/support/differ"

require_relative "support/builders"
require_relative "support/checksums"
require_relative "support/filters"
require_relative "support/helpers"
require_relative "support/indexes"
require_relative "support/matchers"
require_relative "support/permissions"
require_relative "support/platforms"
require_relative "support/rubygems_ext"

$debug = false

module Gem
  def self.ruby=(ruby)
    @ruby = ruby
  end
end

RSpec.configure do |config|
  config.include Spec::Builders
  config.include Spec::Checksums
  config.include Spec::Helpers
  config.include Spec::Indexes
  config.include Spec::Matchers
  config.include Spec::Path
  config.include Spec::Platforms
  config.include Spec::Permissions

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.silence_filter_announcements = !ENV["TEST_ENV_NUMBER"].nil?

  config.backtrace_exclusion_patterns <<
    %r{./spec/(spec_helper\.rb|support/.+)}

  config.disable_monkey_patching!

  # Since failures cause us to keep a bunch of long strings in memory, stop
  # once we have a large number of failures (indicative of core pieces of
  # bundler being broken) so that running the full test suite doesn't take
  # forever due to memory constraints
  config.fail_fast ||= 25 if ENV["CI"]

  config.bisect_runner = :shell

  config.expect_with :rspec do |c|
    c.syntax = :expect

    c.max_formatted_output_length = 1000
  end

  config.mock_with :rspec do |mocks|
    mocks.allow_message_expectations_on_nil = false
  end

  config.before :suite do
    Spec::Rubygems.test_setup
  end

  config.after :suite do
    Spec::Rubygems.test_teardown
  end

  config.around :each do |example|
    FileUtils.cp_r pristine_system_gem_path, system_gem_path

    with_gem_path_as(system_gem_path) do
      Bundler.ui.silence { example.run }

      all_output = all_commands_output
      if example.exception && !all_output.empty?
        message = all_output + "\n" + example.exception.message
        (class << example.exception; self; end).send(:define_method, :message) do
          message
        end
      end
    end
  ensure
    reset!
  end
end
