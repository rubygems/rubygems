# frozen_string_literal: true

# Allows for declaring a Gemfile inline in a ruby script, optionally installing
# any gems that aren't already installed on the user's system.
#
# @note Every gem that is specified in this 'Gemfile' will be `require`d, as if
#       the user had manually called `Bundler.require`. To avoid a requested gem
#       being automatically required, add the `:require => false` option to the
#       `gem` dependency declaration.
#
# @param install [Boolean] whether gems that aren't already installed on the
#                          user's system should be installed.
#                          Defaults to `false`.
#
# @param gemfile [Proc]    a block that is evaluated as a `Gemfile`.
#
# @example Using an inline Gemfile
#
#          #!/usr/bin/env ruby
#
#          require 'bundler/inline'
#
#          gemfile do
#            source 'https://rubygems.org'
#            gem 'json', require: false
#            gem 'nap', require: 'rest'
#            gem 'cocoapods', '~> 0.34.1'
#          end
#
#          puts Pod::VERSION # => "0.34.4"
#
def gemfile(install = false, options = {}, &gemfile)
  require_relative "../bundler"
  Bundler.reset!

  opts = options.dup
  ui = opts.delete(:ui) { Bundler::UI::Shell.new }
  ui.level = "silent" if opts.delete(:quiet) || !install
  Bundler.ui = ui
  raise ArgumentError, "Unknown options: #{opts.keys.join(", ")}" unless opts.empty?

  Bundler.with_unbundled_env do
    Bundler.instance_variable_set(:@bundle_path, Pathname.new(Gem.dir))
    Bundler::SharedHelpers.set_env "BUNDLE_GEMFILE", "Gemfile"

    Bundler::Plugin.gemfile_install(&gemfile) if Bundler.feature_flag.plugins?
    builder = Bundler::Dsl.new
    builder.instance_eval(&gemfile)
    builder.check_primary_source_safety

    Bundler.settings.temporary(deployment: false, frozen: false) do
      definition = builder.to_definition(nil, true)
      def definition.lock(*); end
      definition.validate_runtime!

      if install || definition.missing_specs?
        do_install = -> do
          Bundler.settings.temporary(inline: true, no_install: false) do
            installer = Bundler::Installer.install(Bundler.root, definition, system: true)
            installer.post_install_messages.each do |name, message|
              Bundler.ui.info "Post-install message from #{name}:\n#{message}"
            end
          end
        end

        # When possible we do the install in a subprocess because to install
        # gems we need to require some default gems like `securerandom` etc
        # which may later conflict with the Gemfile requirements.
        if Process.respond_to?(:fork)
          _, status = Process.waitpid2(Process.fork(&do_install))
          exit(status.exitstatus || status.to_i) unless status.success?

          # If the install succeeded, we need to refresh gem info
          Bundler.reset!

          builder = Bundler::Dsl.new
          builder.instance_eval(&gemfile)
          builder.check_primary_source_safety

          definition = builder.to_definition(nil, true)
          def definition.lock(*); end
          definition.validate_runtime!
        else
          do_install.call
        end
      end

      runtime = Bundler::Runtime.new(nil, definition)
      runtime.setup.require
    end
  end

  if ENV["BUNDLE_GEMFILE"].nil?
    ENV["BUNDLE_GEMFILE"] = ""
  end
end
