#!/usr/bin/env ruby

module Gem

  class CommandLineError < Gem::Exception; end

  module CommandAids
    def get_one_gem_name
      args = options[:args]
      if args.nil? or args.empty?
        fail Gem::CommandLineError,
          "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
      end
      if args.size > 1
        fail Gem::CommandLineError,
          "Too many gem names (#{args.join(', ')}); please specify only one"
      end
      args.first
    end

    def get_one_optional_argument
      args = options[:args] || []
      args.first
    end

    def begins?(long, short)
      return false if short.nil?
      long[0, short.length] == short
    end
  end

  module LocalRemoteOptions
    def add_local_remote_options
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

    def local?
      options[:domain] == :local || options[:domain] == :both
    end

    def remote?
      options[:domain] == :remote || options[:domain] == :both
    end
  end

  module InstallUpdateOptions
    def add_install_update_options
      add_option('-i', '--install-dir DIR', '') do |value, options|
        options[:install_dir] = value
      end
      add_option('-d', '--[no-]rdoc', 'Generate RDoc documentation for the gem on install') do |value, options|
        options[:generate_rdoc] = value
      end
      add_option('-f', '--[no-]force', 'Force gem to install, bypassing dependency checks') do |value, options|
        options[:force] = value
      end
      add_option('-t', '--[no-]test', 'Run unit tests prior to installation') do |value, options|
        options[:test] = value
      end
      add_option('-s', '--[no-]install-stub', 'Install a library stub in site_ruby') do |value, options|
        options[:stub] = value
      end
    end
  end

  ####################################################################
  class InstallCommand < Command
    include CommandAids
    include LocalRemoteOptions
    include InstallUpdateOptions

    def initialize
      super(
        'install',
        'Install a gem into the local repository',
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
      add_local_remote_options
      add_install_update_options
    end
    
    def usage
      "#{program_name} GEMNAME"
    end

    def arguments
      "GEMNAME   name of gem to install"
    end

    def execute
      gem_name = get_one_gem_name
      if local?
        begin
          say "Attempting local installation of '#{gem_name}'"
          filename = gem_name
          filename += ".gem" unless File.exist?(filename)
          unless File.exist?(filename)
            if options[:domain] == :both
              say "Local gem file not found: #{filename}"
            else
              alert_error "Local gem file not found: #{filename}"
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
          return
        end
      end
      
      if remote? && installed_gems.nil?
        say "Attempting remote installation of '#{gem_name}'"
        installer = Gem::RemoteInstaller.new(options[:http_proxy])
        installed_gems = installer.install(gem_name, options[:version], options[:force], options[:install_dir], options[:stub])
        say "Successfully installed #{installed_gems[0].name}, version #{installed_gems[0].version}" if installed_gems
      end
      
      unless installed_gems
        alert_error "Could not install a local or remote copy of the gem: #{gem_name}"
        terminate_interaction(1)
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
    end
    
  end
  
  ####################################################################
  class UninstallCommand < Command
    include CommandAids

    def initialize
      super('uninstall', 'Uninstall a gem from the local repository', {:version=>"> 0"})
      add_option('-v', '--version VERSION', 'Specify version of gem to uninstall') do |value, options|
        options[:version] = value
      end
    end
    
    def usage
      "#{program_name} GEMNAME"
    end

    def arguments
      "GEMNAME   name of gem to uninstall"
    end

    def execute
      gem_name = get_one_gem_name
      say "Attempting to uninstall gem '#{gem_name}'"
      Gem::Uninstaller.new(gem_name, options[:version]).uninstall
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
    
    def execute
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
          return
        end
        unless File.exist?(gem_name)
          alert_error "Unknown file: #{gem_name}."
          return
        end
        say "Verifying gem: '#{gem_name}'"
        begin
          Gem::Validator.new.verify_gem_file(gem_name)
        rescue Exception => e
          alert_error "#{gem_name} is invalid."
        end
      end
    end
    
  end # class

  ####################################################################
  class BuildCommand < Command
    include CommandAids

    def initialize
      super('build', 'Build a gem from a gemspec')
    end

    def usage
      "#{program_name} GEMSPEC_FILE"
    end

    def arguments
      "GEMSPEC_FILE      name of gemspec file used to build the gem"
    end

    def execute
      gemspec = get_one_gem_name
      if File.exist?(gemspec)
        say "Attempting to build gem spec '#{gemspec}'"
        begin
          specs = load_gemspecs(gemspec)
          specs.each do |spec|
            Gem::Builder.new(spec).build
          end
          return
        rescue => err
          alert_error "Unexpected error building gemspec #{gemspec}: #{err}\nDetails:\n#{err.backtrace}"
        end
      else
        alert_error "Gemspec file not found: #{gemspec}"
      end
    end

    def load_gemspecs(filename)
      if yaml?(filename)
        require 'yaml'
        result = []
        open(filename) do |f|
          while spec = YAML.load(f)
            result << spec
          end
        end
      else
        load filename
        result = Gem::Specification.list
      end
      result
    end

    def yaml?(filename)
      line = open(filename) { |f| line = f.gets }
      result = line =~ %r{^--- *!ruby/object:Gem::Specification}
      result
    end

  end

  ####################################################################
  class QueryCommand < Command
    include LocalRemoteOptions
      
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
      add_local_remote_options
    end
    
    def execute
      if local?
        say
        say "*** LOCAL GEMS ***"
        output_query_results(Gem::cache.search(options[:name]))
      end
      if remote?
        say
        say "*** REMOTE GEMS ***"
        begin
          output_query_results(Gem::RemoteInstaller.new(options[:http_proxy]).search(options[:name]))
        rescue Gem::RemoteSourceException => e
          alert_error e.to_s
        end
      end
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
        list_of_matching = list_of_matching.sort_by { |x| x.version }.reverse
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
  class ListCommand < QueryCommand
    include CommandAids

    def initialize
      super(
        'list',
        'Display all gems whose name starts with STRING'
      )
      remove_option('--name-matches')
    end

    def usage
      "#{program_name} [STRING]"
    end

    def arguments
      "STRING   start of gem name to look for"
    end

    def execute
      string = get_one_optional_argument || ''
      options[:name] = /^#{string}/i
      super
    end
  end

  ####################################################################
  class SearchCommand < QueryCommand
    include CommandAids

    def initialize
      super(
        'search',
        'Display all gems whose name contains STRING'
      )
      remove_option('--name-matches')
    end

    def usage
      "#{program_name} [STRING]"
    end

    def arguments
      "STRING   fragment of gem name to look for"
    end

    def execute
      string = get_one_optional_argument
      options[:name] = /#{string}/i
      super
    end
  end

  ####################################################################
  class UpdateCommand < Command
    include InstallUpdateOptions

    def initialize
      super(
        'update',
        'Upgrade all currently installed gems in the local repository',
        {:stub=>true, :generate_rdoc=>false}
        )
      add_install_update_options
    end
    
    def execute
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
      install_command = command_manager['install']
      gems_to_update.uniq.sort.each do |name|
        say "Attempting remote upgrade of #{name}"
        options[:args] = [name]
        install_command.merge_options(options)
        install_command.execute
      end
      say "All gems up to date"
    end

    def command_manager
      Gem::CommandManager.instance
    end
  end

  ####################################################################
  class EnvironmentCommand < Command
    include CommandAids

    def initialize
      super('environment', 'Display RubyGems environmental information')
    end

    def usage
      "#{program_name} [args]"
    end

    def arguments
      args = <<-EOF
        packageversion  display the package version
        gemdir          display the path where gems are installed
        gempath         display path used to search for gems
        version         display the gem format version
        remotesources   display the remote gem servers
        <omitted>       display everything
      EOF
      return args.gsub(/^\s+/, '')
    end

    def execute
      out = ''
      arg = options[:args][0]
      if begins?("packageversion", arg)
        out = Gem::RubyGemsPackageVersion.to_s
      elsif begins?("version", arg)
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
        out << "  - VERSION: #{Gem::RubyGemsVersion} (#{Gem::RubyGemsPackageVersion})\n"
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
  class SpecificationCommand < Command
    include LocalRemoteOptions
    include CommandAids
    
    def initialize
      super('specification', 'Display gem specification (in yaml)', {:domain=>:local, :version=>"> 0.0.0"})
      add_option('-v', '--version VERSION', 'Specify version of gem to examine') do |value, options|
        options[:version] = value
      end
      add_local_remote_options
    end

    def usage
      "#{program_name} GEMFILE"
    end

    def arguments
      "GEMFILE       Name of a .gem file to examine"
    end

    def execute
      if local?
        gem = get_one_gem_name
        gem_specs = Gem::Cache.from_installed_gems.search(gem, options[:version])
        if gem_specs.size > 0
          require 'yaml'
          gem_specs.each {|spec| say spec.to_yaml; say "\n"}
        else
          alert_error "Unknown gem #{gem}"
        end
      end
      
      if remote?
        say "(Remote 'info' operation is not yet implemented.)"
        # NOTE: when we do implement remote info, make sure we don't duplicate huge swabs of
        # local data.  If it's the same, just say it's the same.
      end
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
      add_option('--examples', 'Show examples of using the gem command') do |value, options|
        options[:help_examples] = true
      end
    end

    def usage
      "#{program_name} [arg]"
    end

    def arguments
      args = <<-EOF
        commands      Provide a list of gem commands
        examples      Provide a list of gem command examples
      EOF
      return args.gsub(/^\s+/, '')
    end

    def execute
      arg = options[:args][0]
      if options[:help_commands] || begins?("commands", arg)
        out = "GEM commands are:\n"
        indent = command_manager.command_names.collect {|n| n.size}.max + 4
        command_manager.command_names.each do |cmd_name|
          out << "  gem #{cmd_name}#{" "*(indent - cmd_name.size)}#{command_manager[cmd_name].summary}\n"
        end
        say out
      elsif options[:help_options] || begins?("options", arg)
        say Gem::HELP
      elsif options[:help_examples] || begins?("examples", arg)
        say Gem::EXAMPLES
      elsif begins?("version", arg)
        say "RubyGems version #{Gem::RubyGemsPackageVersion}"
      elsif options[:help]
        command = command_manager[options[:help]]
        if command
          # help with provided command
          command.invoke("--help")
        else
          alert_error "Unknown command #{options[:help]}.  Try gem help commands"
        end
      elsif arg
        possibilities = command_manager.find_command_possibilities(arg.downcase)
        if possibilities.size == 1
          command = command_manager[possibilities.first]
          command.invoke("--help")
        elsif possibilities.size > 1
          alert_warning "Ambiguous command #{arg} (#{possibilities.join(', ')})"
        else
          alert_warning "Unknown command #{arg}. Try gem help commands"
        end
      else
        say Gem::HELP
      end
    end
    
    def command_manager
      Gem::CommandManager.instance
    end
  end

end # module

## Documentation Constants

module Gem

  HELP = %{
    RubyGems is a sophisticated package manager for Ruby.  This is a
    basic help message containing pointers to more information.

      Usage:
        gem -h/--help
        gem -v/--version
        gem command [arguments...] [options...]

      Examples:
        gem install rake
        gem list --local
        gem build package.gemspec
        gem help install

      Further help:
        gem help commands            list all 'gem' commands
        gem help examples            show some examples of usage
        gem help <COMMAND>           show help on COMMAND
                                       (e.g. 'gem help install')
      Further information:
        http://rubygems.rubyforge.org

    Commands may be abbreviated, so long as they are unambiguous.
    e.g. 'gem i rake' is short for 'gem install rake'.
    }.gsub(/^    /, "")

  EXAMPLES = %{
    Some examples of 'gem' usage.

    * Install 'rake', either from local directory or remote server:
    
        gem install rake

    * Install 'rake', only from remote server:

        gem install rake --remote

    * Install 'rake' from remote server, and run unit tests,
      generate RDocs, and not install a library stub:

        gem install --remote rake --test --rdoc --no-install-stub

    * Install 'rake', but only version 0.3.1, even if dependencies
      are not met, and into a specific directory:

        gem install rake --version 0.3.1 --force --install-dir $HOME/.gems

    * List local gems whose name begins with 'D':

        gem list D

    * List local and remote gems whose name contains 'log':

        gem search log --both

    * List only remote gems whose name contains 'log':

        gem search log --remote

    * Uninstall 'rake':

        gem uninstall rake
    
    * Create a gem:

        See http://rubygems.rubyforge.org/wiki/wiki.pl?CreateAGemInTenMinutes

    * See information about RubyGems:
    
        gem environment

    }.gsub(/^    /, "")
    
end
