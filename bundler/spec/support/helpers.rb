# frozen_string_literal: true

require_relative "command_execution"
require_relative "the_bundle"
require_relative "path"

module Spec
  module Helpers
    include Spec::Path

    def reset!
      Dir.glob("#{tmp}/{gems/*,*}", File::FNM_DOTMATCH).each do |dir|
        next if %w[base base_system remote1 rubocop standard gems rubygems . ..].include?(File.basename(dir))
        FileUtils.rm_rf(dir)
      end
      FileUtils.mkdir_p(home)
      FileUtils.mkdir_p(tmpdir)
      reset_paths!
    end

    def reset_paths!
      Bundler.reset!
      Gem.clear_paths
    end

    def the_bundle(*args)
      TheBundle.new(*args)
    end

    def command_executions
      @command_executions ||= []
    end

    def last_command
      command_executions.last || raise("There is no last command")
    end

    def out
      last_command.stdout
    end

    def err
      last_command.stderr
    end

    MAJOR_DEPRECATION = /^\[DEPRECATED\]\s*/

    def err_without_deprecations
      err.gsub(/#{MAJOR_DEPRECATION}.+[\n]?/, "")
    end

    def deprecations
      err.split("\n").select {|l| l =~ MAJOR_DEPRECATION }.join("\n").split(MAJOR_DEPRECATION)
    end

    def exitstatus
      last_command.exitstatus
    end

    def run(cmd, *args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      groups = args.map(&:inspect).join(", ")
      setup = "require 'bundler' ; Bundler.ui.silence { Bundler.setup(#{groups}) }"
      ruby([setup, cmd].join(" ; "), opts)
    end

    def load_error_run(ruby, name, *args)
      cmd = <<-RUBY
        begin
          #{ruby}
        rescue LoadError => e
          warn "ZOMG LOAD ERROR" if e.message.include?("-- #{name}")
        end
      RUBY
      opts = args.last.is_a?(Hash) ? args.pop : {}
      args += [opts]
      run(cmd, *args)
    end

    def bundle(cmd, options = {}, &block)
      bundle_bin = options.delete(:bundle_bin)
      bundle_bin ||= installed_bindir.join("bundle")

      args = options.map do |k, v|
        next if [:env, :requires, :artifice, :dir, :raise_on_error].include?(k)

        case v
        when nil
          next
        when true
          " --#{k}"
        when false
          " --no-#{k}"
        else
          " --#{k} #{v}"
        end
      end.join

      cmd = "#{Gem.ruby} -I#{spec_dir} #{bundle_bin} #{cmd}#{args}"

      sys_exec(cmd, options, &block)
    end

    def bundler(cmd, options = {})
      options[:bundle_bin] = system_gem_path.join("bin/bundler")
      bundle(cmd, options)
    end

    def ruby(ruby, options = {})
      escaped_ruby = ruby.shellescape
      sys_exec(%(#{Gem.ruby} -w -e #{escaped_ruby}), { artifice: nil }.merge(options))
    end

    def load_error_ruby(ruby, name, opts = {})
      ruby(<<-R)
        begin
          #{ruby}
        rescue LoadError => e
          warn "ZOMG LOAD ERROR" if e.message.include?("-- #{name}")
        end
      R
    end

    def gembin(cmd, options = {})
      cmd = bundled_app("bin/#{cmd}") unless cmd.to_s.include?("/")
      sys_exec(cmd.to_s, options)
    end

    def gem_command(command, options = {})
      sys_exec("#{Path.gem_bin} #{command}", options)
    end

    def rake
      "#{Gem.ruby} -S #{ENV["GEM_PATH"]}/bin/rake"
    end

    def git(cmd, path, options = {})
      sys_exec("git #{cmd}", options.merge(dir: path))
    end

    def sys_exec(cmd, options = {})
      env = prepare_env(options)
      dir = options[:dir] || bundled_app
      command_execution = CommandExecution.new(cmd.to_s, dir)

      require "open3"
      require "shellwords"
      Open3.popen3(env, *cmd.shellsplit, chdir: dir) do |stdin, stdout, stderr, wait_thr|
        yield stdin, stdout, wait_thr if block_given?
        stdin.close

        stdout_read_thread = Thread.new { stdout.read }
        stderr_read_thread = Thread.new { stderr.read }
        command_execution.original_stdout = stdout_read_thread.value.strip
        command_execution.original_stderr = stderr_read_thread.value.strip

        status = wait_thr.value
        command_execution.exitstatus = if status.exited?
          status.exitstatus
        elsif status.signaled?
          exit_status_for_signal(status.termsig)
        end
      end

      unless options[:raise_on_error] == false || command_execution.success?
        raise <<~ERROR

          Invoking `#{cmd}` failed with output:
          ----------------------------------------------------------------------
          #{command_execution.stdboth}
          ----------------------------------------------------------------------
        ERROR
      end

      command_executions << command_execution

      command_execution.stdout
    end

    def all_commands_output
      return "" if command_executions.empty?

      "\n\nCommands:\n#{command_executions.map(&:to_s_verbose).join("\n\n")}"
    end

    def config(config = nil, path = bundled_app(".bundle/config"))
      return Psych.load_file(path) unless config
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w") do |f|
        f.puts config.to_yaml
      end
      config
    end

    def global_config(config = nil)
      config(config, home(".bundle/config"))
    end

    def create_file(path, contents = "")
      path = Pathname.new(path).expand_path(bundled_app) unless path.is_a?(Pathname)
      path.dirname.mkpath
      File.open(path.to_s, "w") do |f|
        f.puts strip_whitespace(contents)
      end
    end

    def gemfile(*args)
      contents = args.pop

      if contents.nil?
        read_gemfile
      else
        create_file(args.pop || "Gemfile", contents)
      end
    end

    def lockfile(*args)
      contents = args.pop

      if contents.nil?
        read_lockfile
      else
        create_file(args.pop || "Gemfile.lock", contents)
      end
    end

    def read_gemfile(file = "Gemfile")
      read_bundled_app_file(file)
    end

    def read_lockfile(file = "Gemfile.lock")
      read_bundled_app_file(file)
    end

    def read_bundled_app_file(file)
      bundled_app(file).read
    end

    def strip_whitespace(str)
      # Trim the leading spaces
      spaces = str[/\A\s+/, 0] || ""
      str.gsub(/^#{spaces}/, "")
    end

    def install_gemfile(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      gemfile(*args)
      bundle :install, opts
    end

    def lock_gemfile(*args)
      gemfile(*args)
      opts = args.last.is_a?(Hash) ? args.last : {}
      bundle :lock, opts
    end

    def system_gems(*gems)
      gems = gems.flatten
      options = gems.last.is_a?(Hash) ? gems.pop : {}
      install_dir = options.fetch(:path, system_gem_path)
      default = options.fetch(:default, false)
      with_gem_path_as(install_dir) do
        gem_repo = options.fetch(:gem_repo, gem_repo1)
        gems.each do |g|
          gem_name = g.to_s
          if gem_name.start_with?("bundler")
            version = gem_name.match(/\Abundler-(?<version>.*)\z/)[:version] if gem_name != "bundler"
            with_built_bundler(version) {|gem_path| install_gem(gem_path, install_dir, default) }
          elsif %r{\A(?:[a-zA-Z]:)?/.*\.gem\z}.match?(gem_name)
            install_gem(gem_name, install_dir, default)
          else
            install_gem("#{gem_repo}/gems/#{gem_name}.gem", install_dir, default)
          end
        end
      end
    end

    def install_gem(path, install_dir, default = false)
      raise "OMG `#{path}` does not exist!" unless File.exist?(path)

      args = "--no-document --ignore-dependencies --verbose --local --install-dir #{install_dir}"
      args += " --default" if default

      gem_command "install #{args} '#{path}'"
    end

    def with_built_bundler(version = nil, &block)
      Builders::BundlerBuilder.new(self, "bundler", version)._build(&block)
    end

    def with_gem_path_as(path)
      without_env_side_effects do
        ENV["GEM_HOME"] = path.to_s
        ENV["GEM_PATH"] = path.to_s
        ENV["BUNDLER_ORIG_GEM_HOME"] = nil
        ENV["BUNDLER_ORIG_GEM_PATH"] = nil
        yield
      end
    end

    def with_path_as(path)
      without_env_side_effects do
        ENV["PATH"] = path.to_s
        ENV["BUNDLER_ORIG_PATH"] = nil
        yield
      end
    end

    def without_env_side_effects
      backup = ENV.to_hash
      yield
    ensure
      ENV.replace(backup)
    end

    def with_path_added(path)
      with_path_as([path.to_s, ENV["PATH"]].join(File::PATH_SEPARATOR)) do
        yield
      end
    end

    def opt_add(option, options)
      [option.strip, options].compact.reject(&:empty?).join(" ")
    end

    def opt_remove(option, options)
      return unless options

      options.split(" ").reject {|opt| opt.strip == option.strip }.join(" ")
    end

    def break_git!
      FileUtils.mkdir_p(tmp("broken_path"))
      File.open(tmp("broken_path/git"), "w", 0o755) do |f|
        f.puts "#!/usr/bin/env ruby\nSTDERR.puts 'This is not the git you are looking for'\nexit 1"
      end

      ENV["PATH"] = "#{tmp("broken_path")}:#{ENV["PATH"]}"
    end

    def with_fake_man
      skip "fake_man is not a Windows friendly binstub" if Gem.win_platform?

      FileUtils.mkdir_p(tmp("fake_man"))
      File.open(tmp("fake_man/man"), "w", 0o755) do |f|
        f.puts "#!/usr/bin/env ruby\nputs ARGV.inspect\n"
      end
      with_path_added(tmp("fake_man")) { yield }
    end

    def pristine_system_gems(*gems)
      FileUtils.rm_rf(system_gem_path)

      system_gems(*gems)
    end

    def realworld_system_gems(*gems)
      gems = gems.flatten
      opts = gems.last.is_a?(Hash) ? gems.pop : {}
      path = opts.fetch(:path, system_gem_path)

      with_gem_path_as(path) do
        gems.each do |gem|
          gem_command "install --no-document #{gem}"
        end
      end
    end

    def cache_gems(*gems, gem_repo: gem_repo1)
      gems = gems.flatten

      FileUtils.rm_rf("#{bundled_app}/vendor/cache")
      FileUtils.mkdir_p("#{bundled_app}/vendor/cache")

      gems.each do |g|
        path = "#{gem_repo}/gems/#{g}.gem"
        raise "OMG `#{path}` does not exist!" unless File.exist?(path)
        FileUtils.cp(path, "#{bundled_app}/vendor/cache")
      end
    end

    def simulate_new_machine
      FileUtils.rm_rf bundled_app(".bundle")
      pristine_system_gems :bundler
    end

    def simulate_ruby_platform(ruby_platform)
      old = ENV["BUNDLER_SPEC_RUBY_PLATFORM"]
      ENV["BUNDLER_SPEC_RUBY_PLATFORM"] = ruby_platform.to_s
      yield
    ensure
      ENV["BUNDLER_SPEC_RUBY_PLATFORM"] = old
    end

    def simulate_platform(platform)
      old = ENV["BUNDLER_SPEC_PLATFORM"]
      ENV["BUNDLER_SPEC_PLATFORM"] = platform.to_s
      yield if block_given?
    ensure
      ENV["BUNDLER_SPEC_PLATFORM"] = old if block_given?
    end

    def simulate_windows(platform = x86_mswin32)
      old = ENV["BUNDLER_SPEC_WINDOWS"]
      ENV["BUNDLER_SPEC_WINDOWS"] = "true"
      simulate_platform platform do
        yield
      end
    ensure
      ENV["BUNDLER_SPEC_WINDOWS"] = old
    end

    def current_ruby_minor
      Gem.ruby_version.segments.tap {|s| s.delete_at(2) }.join(".")
    end

    def next_ruby_minor
      ruby_major_minor.map.with_index {|s, i| i == 1 ? s + 1 : s }.join(".")
    end

    def previous_ruby_minor
      return "2.7" if ruby_major_minor == [3, 0]

      ruby_major_minor.map.with_index {|s, i| i == 1 ? s - 1 : s }.join(".")
    end

    def ruby_major_minor
      Gem.ruby_version.segments[0..1]
    end

    def revision_for(path)
      sys_exec("git rev-parse HEAD", dir: path).strip
    end

    def with_read_only(pattern)
      chmod = lambda do |dirmode, filemode|
        lambda do |f|
          mode = File.directory?(f) ? dirmode : filemode
          File.chmod(mode, f)
        end
      end

      Dir[pattern].each(&chmod[0o555, 0o444])
      yield
    ensure
      Dir[pattern].each(&chmod[0o755, 0o644])
    end

    # Simulate replacing TODOs with real values
    def prepare_gemspec(pathname)
      process_file(pathname) do |line|
        case line
        when /spec\.metadata\["(?:allowed_push_host|homepage_uri|source_code_uri|changelog_uri)"\]/, /spec\.homepage/
          line.gsub(/\=.*$/, '= "http://example.org"')
        when /spec\.summary/
          line.gsub(/\=.*$/, '= "A short summary of my new gem."')
        when /spec\.description/
          line.gsub(/\=.*$/, '= "A longer description of my new gem."')
        else
          line
        end
      end
    end

    def process_file(pathname)
      changed_lines = pathname.readlines.map do |line|
        yield line
      end
      File.open(pathname, "w") {|file| file.puts(changed_lines.join) }
    end

    def with_env_vars(env_hash, &block)
      current_values = {}
      env_hash.each do |k, v|
        current_values[k] = ENV[k]
        ENV[k] = v
      end
      block.call if block_given?
      env_hash.each do |k, _|
        ENV[k] = current_values[k]
      end
    end

    def require_rack
      # need to hack, so we can require rack
      old_gem_home = ENV["GEM_HOME"]
      ENV["GEM_HOME"] = Spec::Path.base_system_gem_path.to_s
      require "rack"
      ENV["GEM_HOME"] = old_gem_home
    end

    def wait_for_server(host, port, seconds = 15)
      tries = 0
      sleep 0.5
      TCPSocket.new(host, port)
    rescue StandardError => e
      raise(e) if tries > (seconds * 2)
      tries += 1
      retry
    end

    def find_unused_port
      port = 21_453
      begin
        port += 1 while TCPSocket.new("127.0.0.1", port)
      rescue StandardError
        false
      end
      port
    end

    def exit_status_for_signal(signal_number)
      # For details see: https://en.wikipedia.org/wiki/Exit_status#Shell_and_scripts
      128 + signal_number
    end

    private

    def prepare_env(options)
      env = options.delete(:env) || {}
      requires = options.delete(:requires) || []

      current_example = RSpec.current_example

      if current_example
        artifice = options.delete(:artifice) do
          if current_example.metadata[:realworld]
            "vcr"
          else
            "fail"
          end
        end

        if artifice
          requires << "#{artifice_dir}/#{artifice}.rb"
        end
      end

      rubyopt = env["RUBYOPT"] || ""

      rubyopt = opt_add(ENV["RUBYOPT"], rubyopt) if ENV["RUBYOPT"]

      requires.each do |r|
        rubyopt = opt_add("-r#{r}", rubyopt)
      end

      rubyopt = opt_add("-r#{hax}", rubyopt)
      rubyopt = opt_add("-r#{switch}", rubyopt)

      env["RUBYOPT"] = rubyopt
      env
    end

    def git_root_dir?
      root.to_s == `git rev-parse --show-toplevel`.chomp
    end
  end
end
