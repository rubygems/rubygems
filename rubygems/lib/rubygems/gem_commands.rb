#!/usr/bin/env ruby

module Gem

  class CommandLineError < Gem::Exception; end

  module CommandAids
    def get_one_gem_name(options)
      args = options[:args]
      if args.nil? || args.size == 0
	fail Gem::CommandLineError,
	  "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
      end
      if args.size > 1
	fail Gem::CommandLineError,
	  "Too many gem names (#{args.join(', ')}), please specify only one"
      end
      args.first
    end

    def begins?(long, short)
      return false if short.nil?
      long[0, short.length] == short
    end
  end

  ####################################################################
  class HelpCommand < Command
    include CommandAids

    def initialize
      super('help', "Provide help on the gem command")
      add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
	options[:help] = value.nil? ? true : value
      end
      add_option('--commands', 'List available commands') do |value, options|
	options[:help_commands] = true
      end
      add_option('--options', 'List available options on base gem command') do |value, options|
	options[:help_options] = true
      end
      add_option('--examples', 'Show examples of using the gem command') do |value, options|
	options[:help_examples] = true
      end
    end

    def execute(options)
      arg = options[:args][0]
      if options[:help_commands] || begins?("commands", arg)
	out = "GEM commands are:\n"
	indent = command_manager.command_names.collect {|n| n.size}.max+4
	command_manager.command_names.each do |cmd_name|
	  out << "  gem #{cmd_name}#{" "*(indent - cmd_name.size)}#{command_manager[cmd_name].summary}\n"
	end
	say out
	return true
      elsif options[:help_options] || begins?("options", arg)
	return false
      elsif options[:help_examples] || begins?("examples", arg)
	say Gem::EXAMPLES
	return true
      elsif options[:help]
	command = command_manager[options[:help]]
	if command
	  # help with provided command
	  command.invoke("--help")
	  return true
	else
	  alert_error "Unknown command #{options[:help]}.  Try gem --help-commands"
	  return true
	end
      else
	say Gem::HELP
	return true
      end
    end
    
    def command_manager
      Gem::CommandManager.instance
    end
  end

  ####################################################################
  class InstallCommand < Command
    include CommandAids

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
      add_option('-v', '--version VERSION', 'Specify version of gem to install') do |value, options|
	options[:version] = value
      end
      add_option('-l', '--local', 'Restrict operations to the LOCAL domain') do |value, options|
	options[:domain] = :local
      end
      add_option('-r', '--remote', 'Restrict operations to the REMOTE domain') do |value, options|
	options[:domain] = :remote
      end
      add_option('-b', '--both', 'Allow operations on both the LOCAL and REMOTE domains') do |value, options|
	options[:domain] = :both
      end
      add_option('-d', '--gen-rdoc', 'Generate RDoc documentation for the gem on install') do |value, options|
	options[:generate_rdoc] = true
      end
      add_option('-i', '--install-dir DIR', '') do |value, options|
	options[:install_dir] = value
      end
      add_option('-f', '--force', 'Force gem to install, bypassing dependency checks') do |value, options|
	options[:force] = true
      end
      add_option('-t', '--test', 'Run unit tests prior to installation') do |value, options|
	options[:test] = true
      end
      add_option('-s', '--install-stub', 'Install a library stub in site_ruby') do |value, options|
	options[:stub] = true
      end
      add_option('--no-install-stub', 'Do not install a library stub in site_ruby') do |value, options|
	options[:stub] = false
      end
    end
    
    def execute(options)
      return false if options[:help]
      gem_name = get_one_gem_name(options)
      if options[:domain] == :both || options[:domain] == :local
	begin
	  say "Attempting local installation of '#{options[:name]}'"
	  filename = gem_name
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
	  alert_error "Error installing gem #{gem_name}[.gem]: #{e.message}"
	  return true # If a local installation actually fails, we don't try remote.
	end
      end
      
      if options[:domain] == :remote || options[:domain]==:both && installed_gems.nil?
	begin
	  say "Attempting remote installation of '#{gem_name}'"
	  installer = Gem::RemoteInstaller.new(options[:http_proxy])
	  installed_gems = installer.install(gem_name, options[:version], options[:force], options[:install_dir], options[:stub])
	  say "Successfully installed #{installed_gems[0].name}, version #{installed_gems[0].version}" if installed_gems
	rescue RemoteError => e
	  say " -> Remote installation can't proceed: #{e.message}"
	rescue GemNotFoundException => e
	  say "Remote gem file not found: #{gem_name}"
	rescue => e
	  alert_error "Error remotely installing gem #{gem_name}: #{e.message + e.backtrace.join("\n")}"
	  return true
	end
      end
      
      unless installed_gems
	alert_error "Could not install a local or remote copy of the gem: #{gem_name}"
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
    include CommandAids

    def initialize
      super('uninstall', 'Uninstall a gem from the local repository', {:version=>"> 0"})
      add_option('-v', '--version VERSION', 'Specify version of gem to install') do |value, options|
	options[:version] = value
      end
    end
    
    def execute(options)
      return false if options[:help]
      gem_name = get_one_gem_name(options)
      say "Attempting to uninstall gem '#{gem_name}'"
      begin
	Gem::Uninstaller.new(gem_name, options[:version]).uninstall
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
    include CommandAids

    def initialize
      super('build', 'Build a gem from a gemspec')
    end
    
    def execute(options)
      return false if options[:help]
      gemspec = get_one_gem_name(options)
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
      
    def initialize(name='query', summary='Query gem information in local or remote repositories')
      super(name,
	summary,
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

  class ListCommand < QueryCommand
    def initialize
      super('list', 'Alias for query')
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
      add_option('-f', '--force', 'Force gem to install, bypassing dependency checks') do |value, options|
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

  ####################################################################
  class EnvironmentCommand < Command
    include CommandAids

    def initialize
      super('environment', 'RubyGems Environmental Information')
    end

    def execute(options)
      out = ''
      arg = options[:args][0]
      if begins?("version", arg)
	out = Gem::RubyGemsVersion.to_s
      elsif begins?("gemdir", arg)
	out = Gem.dir
      elsif begins?("gempath", arg)
	Gem.path.collect { |p| out << "#{p}\n" }
      elsif begins?("remotesources", arg)
	Gem::RemoteInstaller.new.get_cache_sources.collect do |s|
	  out << "#{s}\n"
	end
      elsif arg
	fail Gem::CommandLineError, "Unknown enviroment option [#{arg}]"
      else
	out = "Rubygems Environment:\n"
	out << "  - VERSION: #{Gem::RubyGemsVersion}\n"
	out << "  - INSTALLATION DIRECTORY: #{Gem.dir}\n"
	out << "  - GEM PATH:\n"
	Gem.path.collect { |p| out << "     - #{p}\n" }
	out << "  - REMOTE SOURCES:\n"
	Gem::RemoteInstaller.new.get_cache_sources.collect do |s|
	  out << "     - #{s}\n"
	end
      end
      say out
      true
    end
  end

  ####################################################################
  class VersionCommand < Command
    def initialize
      super('version', 'RubyGems Version')
    end

    def execute(options)
      say Gem::RubyGemsVersion
      true
    end
  end

end # module

## Documentation Constants

module Gem

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

   Use:
      gem help examples           for a list of examples
      gem help commands           for a list of commands
      gem help                    for this message

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
    
        gem install rake

    * Install 'rake', only from remote server:

        gem install rake --remote

    * Install 'rake' from remote server, and run unit tests,
      generate RDocs, and not install a library stub:

        gem install --remote rake --test --gen-rdoc --no-install-stub

    * Install 'rake', but only version 0.3.1, even if dependencies
      are not met, and into a specific directory:

        gem install rake --version 0.3.1 --force --install-dir $HOME/.gems

    * Query local and remote gems beginning with 'D':

        gem query --name-match ^D

    * List all local, and all remote, gems:

        gem query --local
        gem query --remote
     or
        gem list --local
        gem list --remote

    * Search for local and remote gems including the string 'log':

        gem query --name-matches log --both

    * See information about all versions of 'rake' installed:

        gem query --name-matches rake --details
    
    * Uninstall 'rake':

        gem uninstall rake

    * See information about RubyGems:
    
        gem rubygems-info

    * See summary of all options:
    
        gem --help-options
    }.gsub(/^    /, "")
    
end
