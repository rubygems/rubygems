require 'rubygems'
require 'rubygems/command'

module Gem

  # Signals that local installation will not proceed, not that it has been tried and
  # failed.  TODO: better name.
  class LocalInstallationError < StandardError; end

  # Signals that a remote operation cannot be conducted, probably due to not being
  # connected (or just not finding host).
  #
  # TODO: create a method that tests connection to the preferred gems server.  All code
  # dealing with remote operations will want this.  Failure in that method should raise
  # this error.
  class RemoteError < StandardError; end

  class CommandManager
    def initialize
      @commands = {}
      @base_command = BaseCommand.new
      @base_command.program_name = "gem [command]"
      register_command InstallCommand.new
      register_command UninstallCommand.new
      register_command CheckCommand.new
      register_command BuildCommand.new
      register_command QueryCommand.new
      register_command UpdateCommand.new
    end
    
    def register_command(command)
      @commands[command.command.intern] = command
    end
    
    def [](command_name)
      @commands[command_name.intern]
    end
    
    def command_names
      @commands.keys.collect {|key| key.to_s}.sort
    end
    
    def process_args(args)
      args = args.to_str.split(/\s/) if args.respond_to?(:to_str)
      if args.size==0
        @base_command.invoke(*args)
      elsif args[0]=~/--/
        @base_command.invoke(*args)
      else
        cmd_name = args.shift
        cmd = self[cmd_name]
        raise "Unknown command #{cmd_name}" unless cmd
        #load_config_file_options(args)
        cmd.invoke(*args)
      end
    end
    
    #  - a config file may be specified on the command line
    #  - if it's specified multiple times, the first one wins 
    #  - there is a default config file location HOME/.gemrc
    def load_config_file_options(args)
      config_file = File.join(ENV['HOME'], ".gemrc")
      if args.index("--config-file")
        config_file = args[args.index("--config-file")+1]
      end
      if File.exist?(config_file)
        @config_file_options = YAML.load(File.read(config_file))
      else
        alert_error "Config file #{config_file} not found" if options[:config_file]
        terminate_interaction!if options[:config_file]
      end
    end
  end

end

## Singleton instance and command defintions

module Gem;
  class CommandManager
    class << self
      
      def instance
	@cmd_manager ||= CommandManager.new
      end
      
    end # class.self
  end # class

  ####################################################################
  class BaseCommand < Command
    def initialize
      super('base')
      add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
	options[:help] = value.nil? ? true : value
      end
      add_option(nil, '--help-commands', 'List available commands') do |value, options|
	options[:help_commands] = true
      end
      add_option(nil, '--help-options', 'List available options on base gem command') do |value, options|
	options[:help_options] = true
      end
      add_option(nil, '--help-examples', 'Show examples of using the gem command') do |value, options|
	options[:help_examples] = true
      end
    end
    
    def execute(options)
      if options[:help]==true
	say HELP
	return true
      elsif options[:help]
	command = @cmd_manager[options[:help]]
	if command
	  # help with provided command
	  command.invoke("--help")
	  return true
	else
	  alert_error "Unknown command #{options[:help]}.  Try gem --help-commands"
	  return true
	end
      elsif options[:help_commands]
	say "GEM commands are:"
	indent = @cmd_manager.command_names.collect {|n| n.size}.max+4
	@cmd_manager.command_names.each do |cmd_name|
	  say "  #{cmd_name}#{" "*(indent - cmd_name.size)}#{@cmd_manager[cmd_name].summary}"
	end
	return true
      elsif options[:help_options]
	return false
      elsif options[:help_examples]
	say EXAMPLES
	return true
      end
    end
    
  end

  ####################################################################
  class InstallCommand < Command
    def initialize
      super(
	'install',
	'Install a gem from a local file or remote server into the local repository',
	{
	  :domain => :both, 
	  :generate_rdoc => false, 
	  :force => false, 
	  :test => false, 
	  :stub => true, 
	  :version => "> 0",
	  :install_dir => Gem.dir
	})
      add_option('-n', '--name NAME', 'Name of gem to install') do |value, options|
	options[:name] = value
      end
      add_option('-v', '--version VERSION', 'Specify version of gem to install') do |value, options|
	options[:version] = value
      end
      add_option('-l', '--local', 'Restrict operations to the LOCAL domain') do |value, options|
	options[:domain] = :local
      end
      add_option('-r', '--remote', 'Restrict operations to the REMOTE domain') do |value, options|
	options[:domain] = :remote
      end
      add_option('-d', '--gen-rdoc', 'Generate RDoc documentation for the gem on install') do |value, options|
	options[:generate_rdoc] = true
      end
      add_option('-i', '--install-dir DIR', '') do |value, options|
	options[:install_dir] = value
      end
      add_option('-f', '--force', 'Force gem to intall, bypassing dependency checks') do |value, options|
	options[:force] = true
      end
      add_option('-t', '--test', 'Run unit tests prior to installation') do |value, options|
	options[:test] = true
      end
      add_option('-s', '--install-stub', 'Install a library stub in site_ruby/1.x') do |value, options|
	options[:stub] = true
      end
      add_option(nil, '--no-install-stub', 'Do not install a library stub in site_ruby/1.x') do |value, options|
	options[:stub] = false
      end
    end
    
    def execute(options)
      return false if options[:help]
      unless options[:name]
	alert_error "Please specify a gem name with --name or --help for all options"
	return true
      end
      if options[:domain] == :both || options[:domain] == :local
	begin
	  say "Attempting local installation of '#{options[:name]}'"
	  filename = options[:name]
	  filename += ".gem" unless File.exist?(filename)
	  unless File.exist?(filename)
	    if options[:domain] == :both
	      say "Local gem file not found: #{filename}"
	    else
	      alert_error "Local gem file not found: #{filename}"
	      return true
	    end
	  else
	    result = Gem::Installer.new(filename).install(options[:force], options[:install_dir], options[:stub])
	    installed_gems = [result].flatten
	    say "Successfully installed #{installed_gems[0].name}, version #{installed_gems[0].version}" if installed_gems
	  end
	rescue LocalInstallationError => e
	  say " -> Local installation can't proceed: #{e.message}"
	rescue => e
	  alert_error "Error installing gem #{options[:name]}[.gem]: #{e.message}"
	  return true # If a local installation actually fails, we don't try remote.
	end
      end
      
      if options[:domain] == :remote || options[:domain]==:both && installed_gems.nil?
	begin
	  say "Attempting remote installation of '#{options[:name]}'"
	  installer = Gem::RemoteInstaller.new(options[:http_proxy])
	  installed_gems = installer.install(options[:name], options[:version], options[:force], options[:install_dir], options[:stub])
	  say "Successfully installed #{installed_gems[0].name}, version #{installed_gems[0].version}" if installed_gems
	rescue RemoteError => e
	  say " -> Remote installation can't proceed: #{e.message}"
	rescue GemNotFoundException => e
	  say "Remote gem file not found: #{options[:name]}"
	rescue => e
	  alert_error "Error remotely installing gem #{options[:name]}: #{e.message + e.backtrace.join("\n")}"
	  return true
	end
      end
      
      unless installed_gems
	alert_error "Could not install a local or remote copy of the gem: #{options[:name]}"
	return true
      end
      
      if options[:generate_rdoc]
	installed_gems.each do |gem|
	  Gem::DocManager.new(gem, options[:rdoc_args]).generate_rdoc
	end
	# TODO: catch exceptions and inform user that doc generation was not successful.
      end
      
      if options[:test]
	installed_gems.each do |gem|
	  gem_specs = Gem::Cache.from_installed_gems.search(gem.name, gem.version.version)
	  unless gem_specs[0].test_suite_file
	    say "There are no unit tests to run for #{gem.name}-#{gem.version}"
	    next
	  end
	  require_gem name, "= #{gem.version.version}"
	  require gem_specs[0].test_suite_file
	  suite = Test::Unit::TestSuite.new("#{gem.name}-#{gem.version}")
	  ObjectSpace.each_object(Class) do |klass|
	    suite << klass.suite if (Test::Unit::TestCase > klass)
	  end
	  require 'test/unit/ui/console/testrunner'
	  result = Test::Unit::UI::Console::TestRunner.run(suite, Test::Unit::UI::SILENT)
	  unless(result.passed?)
	    answer = ask(result.to_s + "...keep Gem? [Y/n] ")
	    if(answer !~ /^y/i) then
	      Gem::Uninstaller.new(gem.name, gem.version.version).uninstall
	    end
	  end
	end
      end
      return true
    end
    
  end
  
  ####################################################################
  class UninstallCommand < Command
    def initialize
      super('uninstall', 'Uninstall a gem from the local repository', {:version=>"> 0"})
      add_option('-n', '--name NAME', 'Name of gem to uninstall') do |value, options|
	options[:name] = value
      end
      add_option('-v', '--version VERSION', 'Specify version of gem to install') do |value, options|
	options[:version] = value
      end
    end
    
    def execute(options)
      return false if options[:help]
      say "Attempting to uninstall gem '#{options[:name]}'"
      begin
	Gem::Uninstaller.new(options[:name], options[:version]).uninstall
      rescue => e
	alert_error e.message
      end
      true
    end
  end      

  ####################################################################
  class CheckCommand < Command

    def initialize
      super('check', 'Check installed gems',  {:verify => false, :alien => false})
      add_option('-v', '--verify FILE', 'Verify gem file against its internal checksum') do |value, options|
	options[:verify] = value
      end
      add_option('-a', '--alien', "Report 'unmanaged' or rogue files in the gem repository") do |value, options|
	options[:alien] = true
      end
    end
    
    def execute(options)
      return false if options[:help]
      if options[:alien]
	say "Performing the 'alien' operation"
	Gem::Validator.new.alien.each do |key, val|
	  if(val.size > 0)
	    say "#{key} has #{val.size} problems"
	    val.each do |error_entry|
	      say "\t#{error_entry.path}:"
	      say "\t#{error_entry.problem}"
	      say
	    end
	  else  
	    say "#{key} is error-free"
	  end
	  say
	end
      end
      if options[:verify]
	gem_name = options[:verify]
	unless gem_name
	  alert_error "Must specifiy a .gem file with --verify NAME"
	  return true
	end
	unless File.exist?(gem_name)
	  alert_error "Unknown file: #{gem_name}."
	  return true
	end
	say "Verifying gem: '#{gem_name}'"
	begin
	  Gem::Validator.new.verify_gem_file(gem_name)
	rescue Exception => e
	  alert_error "#{gem_name} is invalid."
	end
      end
      return true
    end
    
  end # class

  ####################################################################
  class BuildCommand < Command
    def initialize
      super('build', 'Build a gem from a gemspec')
      add_option('-n', '--name GEMSPEC', 'Build a gem file from its spec') do |value, options|
	options[:name] = value
      end
    end
    
    def execute(options)
      return false if options[:help]
      gemspec = options[:name]
      if File.exist?(gemspec)
	say "Attempting to build gem spec '#{gemspec}'"
	begin
	  load gemspec
	  Gem::Specification.list.each do |spec|
	    Gem::Builder.new(spec).build
	  end
	  return true
	rescue => err
	  alert_error "Unexpected error building gemspec #{gemspec}: #{err}\nDetails:\n#{err.backtrace}"
	end
      else
	alert_error "Gemspec file not found: #{gemspec}"
      end
      return true
    end
  end

  ####################################################################
  class QueryCommand < Command
      
    def initialize
      super('query',
	'Query gem information in local or remote repositories',
	{:name=>/.*/, :domain=>:local, :details=>false}
	)
      add_option('-n', '--name-matches REGEXP', 'Name of gem(s) to query on maches the provided REGEXP') do |value, options|
	options[:name] = Regexp.compile(value)
      end
      add_option('-d', '--details', 'Display detailed information of gem(s)') do |value, options|
	options[:details] = true
      end
      add_option('-l', '--local', 'Restrict operations to the LOCAL domain (default)') do |value, options|
	options[:domain] = :local
      end
      add_option('-r', '--remote', 'Restrict operations to the REMOTE domain') do |value, options|
	options[:domain] = :remote
      end
      add_option('-b', '--both', 'Allow LOCAL and REMOTE operations') do |value, options|
	options[:domain] = :both
      end
    end
    
    def execute(options)
      return false if options[:help]
      if options[:domain]==:local || options[:domain]==:both
	say
	say "*** LOCAL GEMS ***"
	output_query_results(Gem::cache.search(options[:name]))
      end
      if options[:domain]==:remote || options[:domain]==:both
	say
	say "*** REMOTE GEMS ***"
	begin
	  output_query_results(Gem::RemoteInstaller.new(options[:http_proxy]).search(options[:name]))
	rescue Gem::RemoteSourceException => e
	  alert_error e.to_s
	end
      end
      return true
    end

    private

    def output_query_results(gemspecs)
      gem_list_with_version = {}
      gemspecs.flatten.each do |gemspec|
	gem_list_with_version[gemspec.name] ||= []
	gem_list_with_version[gemspec.name] << gemspec
      end
      
      gem_list_with_version = gem_list_with_version.sort do |first, second|
	first[0].downcase <=> second[0].downcase
      end
      gem_list_with_version.each do |gem_name, list_of_matching| 
	say
	list_of_matching.sort! do |a,b|
	  a.version <=> b.version
	end.reverse!
	seen_versions = []
	list_of_matching.delete_if do |item|
	  if(seen_versions.member?(item.version))           
	    true
	  else 
	    seen_versions << item.version
	    false
	  end
	end
	say "#{gem_name} (#{list_of_matching.map{|gem| gem.version.to_s}.join(", ")})"
	say format_text(list_of_matching[0].summary, 68, 4)
      end
    end
    
    ##
    # Used for wrapping and indenting text
    #
    def format_text(text, wrap, indent=0)
      result = []
      pattern = Regexp.new("^(.{0,#{wrap}})[ \n]")
      work = text.dup
      while work.length > wrap
	if work =~ pattern
	  result << $1
	  work.slice!(0, $&.length)
	else
	  result << work.slice!(0, wrap)
	end
      end
      result << work if work.length.nonzero?
      result.join("\n").gsub(/^/, " " * indent)
    end
  end

  ####################################################################
  class UpdateCommand < Command
    def initialize
      super(
	'update',
	'Upgrade all currently installed gems in the local repository',
	{:stub=>true, :generate_rdoc=>false}
	)
      add_option('-d', '--gen-rdoc', 'Generate RDoc documentation for the gem on install') do |value, options|
	options[:generate_rdoc] = value
      end
      add_option('-i', '--install-dir DIR', '') do |value, options|
	options[:install_dir] = value
      end
      add_option('-f', '--force', 'Force gem to intall, bypassing dependency checks') do |value, options|
	options[:force] = true
      end
      add_option('-t', '--test', 'Run unit tests prior to installation') do |value, options|
	options[:test] = true
      end
      add_option('-s', '--install-stub', 'Install a library stub in site_ruby/1.x') do |value, options|
	options[:stub] = true
      end
      add_option(nil, '--no-install-stub', 'Do not install a library stub in site_ruby/1.x') do |value, options|
	options[:stub] = false
      end
    end
    
    def execute(options)
      return false if options[:help]
      say "Upgrading installed gems..."
      hig = highest_installed_gems = {}
      Gem::Cache.from_installed_gems.each do |name, spec|
	if hig[spec.name].nil? or hig[spec.name].version < spec.version
	  hig[spec.name] = spec
	end
      end
      remote_gemspecs = Gem::RemoteInstaller.new(options[:http_proxy]).search(//)
      # For some reason, this is an array of arrays.  The actual list of specifications is
      # the first and only element.  If there were more remote sources, perhaps there would be
      # more.
      remote_gemspecs = remote_gemspecs.flatten
      gems_to_update = []
      highest_installed_gems.each do |l_name, l_spec|
	hrg = highest_remote_gem =
	  remote_gemspecs.select  { |spec| spec.name == l_name }.
	  sort_by { |spec| spec.version }.
	  last
	if hrg and l_spec.version < hrg.version
	  gems_to_update << l_name
	end
      end
      options[:domain] = :remote # install from remote source
      gems_to_update.uniq.sort.each do |name|
	say "Attempting remote upgrade of #{name}"
	process_install_command(options)
      end
      say "All gems up to date"
      return true
    end
  end
end # module

## Documentation Constants

module Gem
  class CommandManager

    HELP = %{
    RubyGems is a sophisticated package manager for Ruby.  This is a
    basic help message containing pointers to more information.
    
    Usage: gem command [common-options] [command-options-and-arguments]
      where common-options are --help, etc.
        (specify --help-options for a list of options)
      where command is install, uninstall, etc.
        (specify --help-commands for a list of commands)
      where command-options-and-arguments depend on the specific command
        (specify --help followed by a command name for command-specific help)
      Specify --help-examples for a list of examples
      Specify --help to receive this message

    For detailed online information, go to http://rubygems.rubyforge.org.
    The following documents, among others, can be found in the
    "Documentation" section:
      * Quick Introduction
      * Users Guide
      * 'gem' Command Line Reference
        -> This includes information about environment variables,
           configuration files, and more.
    }.gsub(/^    /, "")

    EXAMPLES = %{
    Some examples of 'gem' usage.

    * Install 'rake', either from local directory or remote server:
    
        gem install --name rake

    * Install 'rake', only from remote server:

        gem install --name rake --remote

    * Install 'rake' from remote server, and run unit tests,
      generate RDocs, and install library stub:

        gem install --remote --name rake --test --gen-rdoc --install-stub

    * Install 'rake', but only version 0.3.1, even if dependencies
      are not met, and into a specific directory:

        gem install --name rake --version 0.3.1 --force --install-dir $HOME/.gems

    * Query local and remote gems beginning with 'D':

        gem query --name-match ^D

    * List all local, and all remote, gems:

        gem query --local
        gem query --remote

    * Search for local and remote gems including the string 'log':

        gem query --name-matches log --both

    * See information about all versions of 'rake' installed:

        gem query --name-matches rake --details
    
    * Uninstall 'rake':

        gem uninstall --name rake

    * See information about RubyGems:
    
        gem --rubygems-info

    * See summary of all options:
    
        gem --help-options
    }.gsub(/^    /, "")
    
  end
end


