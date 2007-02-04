#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems'
require 'rubygems/command'

module Gem

  class CommandLineError < Gem::Exception; end

  ####################################################################
  # The following mixin methods aid in the retrieving of information
  # from the command line.
  #
  module CommandAids

    # Get the single gem name from the command line.  Fail if there is
    # no gem name or if there is more than one gem name given.
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

    # Get all gem names from the command line.
    def get_all_gem_names
      args = options[:args]
      if args.nil? or args.empty?
        raise Gem::CommandLineError,
              "Please specify at least one gem name (e.g. gem build GEMNAME)"
      end
      gem_names = args.select { |arg| arg !~ /^-/ }
    end

    # Get a single optional argument from the command line.  If more
    # than one argument is given, return only the first. Return nil if
    # none are given.
    def get_one_optional_argument
      args = options[:args] || []
      args.first
    end

    # True if +long+ begins with the characters from +short+.
    def begins?(long, short)
      return false if short.nil?
      long[0, short.length] == short
    end
  end

  ####################################################################
  # Mixin methods for handling the local/remote command line options.
  #
  module LocalRemoteOptions

    # Add the local/remote options to the command line parser.
    def add_local_remote_options
      add_option('-l', '--local',
                 'Restrict operations to the LOCAL domain'
                 ) do |value, options|
        options[:domain] = :local
      end

      add_option('-r', '--remote',
        'Restrict operations to the REMOTE domain') do
        |value, options|
        options[:domain] = :remote
      end

      add_option('-b', '--both',
        'Allow LOCAL and REMOTE operations') do
        |value, options|
        options[:domain] = :both
      end
    end

    # Is local fetching enabled?
    def local?
      options[:domain] == :local || options[:domain] == :both
    end

    # Is remote fetching enabled?
    def remote?
      options[:domain] == :remote || options[:domain] == :both
    end
  end

  ####################################################################
  # Mixin methods and OptionParser options specific to the gem install
  # command.
  #
  module InstallUpdateOptions

    # Add the install/update options to the option parser.
    def add_install_update_options
      add_option('-i', '--install-dir DIR',
                 'Gem repository directory to get installed',
                 'gems.') do |value, options|
        options[:install_dir] = File.expand_path(value)
      end

      add_option('-d', '--[no-]rdoc', 
                 'Generate RDoc documentation for the gem on',
                 'install') do |value, options|
        options[:generate_rdoc] = value
      end

      add_option('--[no-]ri', 
                 'Generate RI documentation for the gem on',
                 'install') do |value, options|
        options[:generate_ri] = value
      end

      add_option('-E', '--env-shebang',
                 "Rewrite the shebang line on installed",
                 "scripts to use /usr/bin/env") do |value, options|
        options[:env_shebang] = value
      end

      add_option('-f', '--[no-]force', 
                 'Force gem to install, bypassing dependency',
                 'checks') do |value, options|
        options[:force] = value
      end

      add_option('-t', '--[no-]test', 
        'Run unit tests prior to installation') do 
        |value, options|
        options[:test] = value
      end

      add_option('-w', '--[no-]wrappers', 
        'Use bin wrappers for executables',
        'Not available on dosish platforms') do 
        |value, options|
        options[:wrappers] = value
      end

      add_option('-P', '--trust-policy POLICY', 
        'Specify gem trust policy.') do 
        |value, options|
        options[:security_policy] = value
      end

      add_option('--ignore-dependencies',
        'Do not install any required dependent gems') do 
        |value, options|
        options[:ignore_dependencies] = value
      end

      add_option('-y', '--include-dependencies',
                 'Unconditionally install the required',
                 'dependent gems') do |value, options|
        options[:include_dependencies] = value
      end
    end
    
    # Default options for the gem install command.
    def install_update_defaults_str
      '--rdoc --no-force --no-test --wrappers'
    end
  end

  ####################################################################
  # Mixin methods for the version command.
  #
  module VersionOption

    # Add the options to the option parser.
    def add_version_option(taskname, *wrap)
      add_option('-v', '--version VERSION', 
                 "Specify version of gem to #{taskname}", *wrap) do 
                   |value, options|
        options[:version] = value
      end
    end

  end

  ####################################################################
  # Gem install command.
  #
  class InstallCommand < Command
    include CommandAids
    include VersionOption
    include LocalRemoteOptions
    include InstallUpdateOptions

    def initialize
      super(
        'install',
        'Install a gem into the local repository',
        {
          :domain => :both, 
          :generate_rdoc => true,
          :generate_ri   => true,
          :force => false, 
          :test => false, 
          :wrappers => true,
          :version => "> 0",
          :install_dir => Gem.dir,
          :security_policy => nil,
        })
      add_version_option('install')
      add_local_remote_options
      add_install_update_options
    end
    
    def usage
      "#{program_name} GEMNAME [options]
   or: #{program_name} GEMNAME [options] -- --build-flags"
    end

    def arguments
      "GEMNAME   name of gem to install"
    end

    def defaults_str
      "--both --version '> 0' --rdoc --ri --no-force --no-test\n" +
      "--install-dir #{Gem.dir}"
    end

    def execute
      ENV['GEM_PATH'] = options[:install_dir]
      if(options[:args].empty?)
        fail Gem::CommandLineError,
          "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
      end
      options[:args].each do |gem_name|
        if local?
          begin
            entries = []
              if(File.exist?(gem_name) && !File.directory?(gem_name))
                entries << gem_name
              else
                filepattern = gem_name + "*.gem"
                entries = Dir[filepattern] 
              end
              unless entries.size > 0
                if options[:domain] == :local
                  alert_error "Local gem file not found: #{filepattern}"
                end
              else
                result = Gem::Installer.new(entries.last, options).install(options[:force],     options[:install_dir])
                installed_gems = [result].flatten
                say "Successfully installed #{installed_gems[0].name}, " +
                "version #{installed_gems[0].version}" if installed_gems
            end
          rescue LocalInstallationError => e
            say " -> Local installation can't proceed: #{e.message}"
          rescue Gem::LoadError => e
            say " -> Local installation can't proceed due to LoadError: #{e.message}"
          rescue Gem::InstallError => e
            raise "Error instaling #{gem_name}:\n\t#{e.message}"
          rescue => e
            # TODO: Fix this handle to allow the error to propagate to
            # the top level handler.  Examine the other errors as
            # well.  This implementation here looks suspicious to me --
            # JimWeirich (4/Jan/05) 
            alert_error "Error installing gem #{gem_name}[.gem]: #{e.message}"
            return
          end
        end
        
        if remote? && installed_gems.nil?
          installer = Gem::RemoteInstaller.new(options)
          installed_gems = installer.install(
            gem_name,
            options[:version],
            options[:force],
            options[:install_dir])
          if installed_gems
            installed_gems.compact!
            installed_gems.each do |spec|
              say "Successfully installed #{spec.full_name}"
            end
          end
        end
        
        unless installed_gems
          alert_error "Could not install a local " +
            "or remote copy of the gem: #{gem_name}"
          terminate_interaction(1)
        end
        
        # NOTE: *All* of the RI documents must be generated first.
        # For some reason, RI docs cannot be generated after any RDoc
        # documents are generated.

        if options[:generate_ri]
          installed_gems.each do |gem|
            Gem::DocManager.new(gem, options[:rdoc_args]).generate_ri
          end
        end

        if options[:generate_rdoc]
          installed_gems.each do |gem|
            Gem::DocManager.new(gem, options[:rdoc_args]).generate_rdoc
          end
        end

        if options[:test]
          installed_gems.each do |spec|
            gem_spec = Gem::SourceIndex.from_installed_gems.search(spec.name, spec.version.version).first
            result = Gem::Validator.new.unit_test(gem_spec)
            unless result.passed?
              unless ask_yes_no("...keep Gem?", true) then
                Gem::Uninstaller.new(spec.name, spec.version.version).uninstall
              end
            end
          end
        end
      end
    end
    
  end
  
  ####################################################################
  class OutdatedCommand < Command

    def initialize
      super 'outdated', 'Display all gems that need updates'
    end

    def execute
      locals = Gem::SourceIndex.from_installed_gems
      locals.outdated.each do |name|
        local = locals.search(/^#{name}$/).last
        remote = Gem::SourceInfoCache.search(/^#{name}$/).last
        say "#{local.name} (#{local.version} < #{remote.version})"
      end
    end

  end

  ####################################################################
  class SourcesCommand < Command

    def initialize
      super 'sources', 'Manage the sources RubyGems will search forgems'

      add_option '-a', '--add SOURCE_URI', 'Add source' do |value, options|
        options[:add] = value
      end

      add_option '-l', '--list', 'List sources' do |value, options|
        options[:list] = value
      end

      add_option '-r', '--remove SOURCE_URI', 'Remove source' do |value, options|
        options[:remove] = value
      end
    end

    def defaults_str
      '--list'
    end

    def execute
      if options[:add] then
        source_uri = options[:add]

        sice = Gem::SourceInfoCacheEntry.new nil, nil
        begin
          sice.refresh source_uri
        rescue ArgumentError
          say "#{source_uri} is not a URI"
        rescue Gem::RemoteFetcher::FetchError => e
          say "Error fetching #{source_uri}:\n\t#{e.message}"
        else
          Gem::SourceInfoCache.cache_data[source_uri] = sice
          Gem::SourceInfoCache.cache.update
          Gem::SourceInfoCache.cache.flush

          say "#{source_uri} added to sources"
        end
      end

      if options[:remove] then
        source_uri = options[:remove]

        unless Gem::SourceInfoCache.cache_data.include? source_uri then
          say "source #{source_uri} not present in cache"
        else
          Gem::SourceInfoCache.cache_data.delete source_uri
          Gem::SourceInfoCache.cache.update
          Gem::SourceInfoCache.cache.flush
          say "#{source_uri} removed from sources"
        end
      end

      if options[:list] or not (options[:add] or options[:remove]) then
        say "*** CURRENT SOURCES ***"
        say

        Gem::SourceInfoCache.cache_data.keys.each do |source_uri|
          say source_uri
        end
      end
    end

  end

  ####################################################################
  class UninstallCommand < Command
    include VersionOption
    include CommandAids

    def initialize
      super('uninstall', 'Uninstall gems from the local repository',
            { :version => "> 0" })

      add_option('-a', '--[no-]all',
        'Uninstall all matching versions'
        ) do |value, options|
        options[:all] = value
      end

        add_option('-i', '--[no-]ignore-dependencies',
                   'Ignore dependency requirements while',
                   'uninstalling') do |value, options|
        options[:ignore] = value
      end

        add_option('-x', '--[no-]executables',
                   'Uninstall applicable executables without',
                   'confirmation') do |value, options|
        options[:executables] = value
      end

      add_version_option('uninstall')
    end

    def defaults_str
      "--version '> 0' --no-force"
    end
    
    def usage
      "#{program_name} GEMNAME [GEMNAME ...]"
    end

    def arguments
      "GEMNAME   name of gem to uninstall"
    end

    def execute
      get_all_gem_names.each do |gem_name|
        Gem::Uninstaller.new(gem_name, options).uninstall
      end
    end
  end

  ####################################################################
  class CertCommand < Command
    include CommandAids
    
    def initialize
      super(
        'cert',
        'Adjust RubyGems certificate settings',
        {
        })

      add_option('-a', '--add CERT', 'Add a trusted certificate.') do |value, options|
        cert = OpenSSL::X509::Certificate.new(File.read(value))
        Gem::Security.add_trusted_cert(cert)
        puts "Added #{cert.subject.to_s}"
      end

      add_option('-l', '--list', 'List trusted certificates.') do |value, options|
        glob_str = File::join(Gem::Security::OPT[:trust_dir], '*.pem')
        Dir::glob(glob_str) do |path|
          cert = OpenSSL::X509::Certificate.new(File.read(path))
          # this could proably be formatted more gracefully
          puts cert.subject.to_s
        end
      end

      add_option('-r', '--remove STRING',
                 'Remove trusted certificates containing',
                 'STRING.') do |value, options|
        trust_dir = Gem::Security::OPT[:trust_dir]
        glob_str = File::join(trust_dir, '*.pem')

        Dir::glob(glob_str) do |path|
          cert = OpenSSL::X509::Certificate.new(File.read(path))
          if cert.subject.to_s.downcase.index(value)
            puts "Removing '#{cert.subject.to_s}'"
            File.unlink(path)
          end
        end
      end

      add_option('-b', '--build EMAIL_ADDR',
                 'Build private key and self-signed',
                 'certificate for EMAIL_ADDR.') do |value, options|
        vals = Gem::Security::build_self_signed_cert(value)
        File::chmod(0600, vals[:key_path])
        puts "Public Cert: #{vals[:cert_path]}",
             "Private Key: #{vals[:key_path]}",
             "Don't forget to move the key file to somewhere private..."
      end

      add_option('-C', '--certificate CERT',
                 'Certificate for --sign command.') do |value, options|
        cert = OpenSSL::X509::Certificate.new(File.read(value))
        Gem::Security::OPT[:issuer_cert] = cert
      end

      add_option('-K', '--private-key KEY',
                 'Private key for --sign command.') do |value, options|
        key = OpenSSL::PKey::RSA.new(File.read(value))
        Gem::Security::OPT[:issuer_key] = key
      end


      add_option('-s', '--sign NEWCERT', 
                 'Sign a certificate with my key and',
                 'certificate.') do |value, options|
        cert = OpenSSL::X509::Certificate.new(File.read(value))
        my_cert = Gem::Security::OPT[:issuer_cert]
        my_key = Gem::Security::OPT[:issuer_key]
        cert = Gem::Security.sign_cert(cert, my_key, my_cert)
        File::open(value, 'wb') { |file| file.write(cert.to_pem) }
      end

    end

    def execute
    end
  end

  ####################################################################
  class DependencyCommand < Command
    include VersionOption
    include CommandAids

    def initialize
      super('dependency',
        'Show the dependencies of an installed gem',
        {:version=>"> 0"})
      add_version_option('dependency')
      add_option('-r', '--[no-]reverse-dependencies',
        'Include reverse dependencies in the output'
        ) do |value, options|
        options[:reverse_dependencies] = value
      end
      add_option('-p', '--pipe', "Pipe Format (name --version ver)") do |value, options|
        options[:pipe_format] = value
      end
    end

    def defaults_str
      "--version '> 0' --no-reverse"
    end
    
    def usage
      "#{program_name} GEMNAME"
    end

    def arguments
      "GEMNAME   name of gems to show"
    end

    def execute
      specs = {}
      srcindex = SourceIndex.from_installed_gems
      options[:args] << '.' if options[:args].empty?
      options[:args].each do |name|
        speclist = srcindex.search(name, options[:version])
        if speclist.empty?
          say "No match found for #{name} (#{options[:version]})"
        else
          speclist.each do |spec|
            specs[spec.full_name] = spec
          end
        end
      end
      reverse = Hash.new { |h, k| h[k] = [] }
      if options[:reverse_dependencies]
        specs.values.each do |spec|
          reverse[spec.full_name] = find_reverse_dependencies(spec, srcindex)
        end
      end
      if options[:pipe_format]
        specs.values.sort.each do |spec|
          unless spec.dependencies.empty?
            spec.dependencies.each do |dep|
              puts "#{dep.name} --version '#{dep.version_requirements}'"
            end
          end
        end     
      else
        response = ''
        specs.values.sort.each do |spec|
          response << print_dependencies(spec)
          unless reverse[spec.full_name].empty?
            response << "  Used by\n"
            reverse[spec.full_name].each do |sp, dep|
              response << "    #{sp} (#{dep})\n"
            end
          end
          response << "\n"
        end
        say response
      end
    end

    def print_dependencies(spec, level = 0)
      response = ''
      response << '  ' * level + "Gem #{spec.full_name}\n"
      unless spec.dependencies.empty?
#        response << '  ' * level + "  Requires\n"
        spec.dependencies.each do |dep|
          response << '  ' * level + "  #{dep}\n"
        end
      end
      response
    end

    # Retuns list of [specification, dep] that are satisfied by spec.
    def find_reverse_dependencies(spec, srcindex)
      result = []
      srcindex.each do |name, sp|
        sp.dependencies.each do |dep|
          if spec.name == dep.name &&
              dep.version_requirements.satisfied_by?(spec.version)
            result << [sp.full_name, dep]
          end
        end
      end
      result
    end

  end      

  ####################################################################
  class CheckCommand < Command
    include CommandAids

    def initialize
      super('check', 'Check installed gems',
            {:verify => false, :alien => false})

      add_option('-v', '--verify FILE',
                 'Verify gem file against its internal',
                 'checksum') do |value, options|
        options[:verify] = value
      end

      add_option('-a', '--alien', "Report 'unmanaged' or rogue files in the",
                 "gem repository") do |value, options|
        options[:alien] = true
      end

      add_option('-t', '--test', "Run unit tests for gem") do |value, options|
        options[:test] = true
      end

      add_option('-V', '--version',
                 "Specify version for which to run unit tests") do |value, options|
        options[:version] = value
      end
    end
    
    def execute
      if options[:test]
        version = options[:version] || "> 0.0.0"
        gem_spec = Gem::SourceIndex.from_installed_gems.search(get_one_gem_name, version).first
        Gem::Validator.new.unit_test(gem_spec)
      end
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
          alert_error "Must specify a .gem file with --verify NAME"
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
        specs = load_gemspecs(gemspec)
        specs.each do |spec|
          Gem::Builder.new(spec).build
        end
        return
      else
        alert_error "Gemspec file not found: #{gemspec}"
      end
    end

    def load_gemspecs(filename)
      if yaml?(filename)
        require 'yaml'
        result = []
        open(filename) do |f|
          begin
            while spec = Gem::Specification.from_yaml(f)
              result << spec
            end
          rescue EndOfYAMLException => e
            # OK
          end
        end
      else
        result = [Gem::Specification.load(filename)]
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
      add_option('-n', '--name-matches REGEXP', 'Name of gem(s) to query on matches the provided REGEXP') do |value, options|
        options[:name] = /#{value}/i
      end
      add_option('-d', '--[no-]details', 'Display detailed information of gem(s)') do |value, options|
        options[:details] = value
      end
      add_local_remote_options
    end

    def defaults_str
      "--local --name-matches '.*' --no-details"
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
        output_query_results(Gem::SourceInfoCache.search(options[:name]))
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

    def defaults_str
      "--local --no-details"
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

    def defaults_str
      "--local --no-details"
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
        'Update the named gem (or all installed gems) in the local repository',
        {
          :generate_rdoc => true, 
          :generate_ri => true, 
          :force => false, 
          :test => false,
          :install_dir => Gem.dir
        })
      add_install_update_options
      add_option('--system',
        'Update the RubyGems system software') do |value, options|
        options[:system] = value
      end
    end
    
    def defaults_str
      "--rdoc --ri --no-force --no-test\n" +
      "--install-dir #{Gem.dir}"
    end

    def arguments
      "GEMNAME(s)   name of gem(s) to update"
    end

    def execute
      if options[:system]
        say "Updating RubyGems..."
        if ! options[:args].empty?
          fail "No gem names are allowed with the --system option"
        end
        options[:args] = ["rubygems-update"]
      else
        say "Updating installed gems..."
      end
      hig = highest_installed_gems = {}
      Gem::SourceIndex.from_installed_gems.each do |name, spec|
        if hig[spec.name].nil? or hig[spec.name].version < spec.version
          hig[spec.name] = spec
        end
      end
      remote_gemspecs = Gem::SourceInfoCache.search(//)
      gems_to_update =  if(options[:args].empty?) then
                          which_to_update(highest_installed_gems, remote_gemspecs)
                        else
                          options[:args]
                        end
      options[:domain] = :remote # install from remote source
      install_command = command_manager['install']
      gems_to_update.uniq.sort.each do |name|
        say "Attempting remote update of #{name}"
        options[:args] = [name]
        install_command.merge_options(options)
        install_command.execute
      end
      if gems_to_update.include?("rubygems-update")
        latest_ruby_gem = remote_gemspecs.select { |s|
          s.name == 'rubygems-update' 
        }.sort_by { |s|
          s.version
        }.last
        say "Updating version of RubyGems to #{latest_ruby_gem.version}"
        do_rubygems_update(latest_ruby_gem.version.to_s)
      end
      if(options[:system]) then
        say "RubyGems system software updated"
      else
        say "Gems: [#{gems_to_update.uniq.sort.collect{|g| g.to_s}.join(', ')}] updated"
      end
    end

    def do_rubygems_update(version_string)
      update_dir = File.join(Gem.dir, "gems", "rubygems-update-#{version_string}")
      Dir.chdir(update_dir) do
        puts "Installing RubyGems #{version_string}"
        system "#{Gem.ruby} setup.rb"
      end
    end

    def which_to_update(highest_installed_gems, remote_gemspecs)
      result = []
      highest_installed_gems.each do |l_name, l_spec|
        highest_remote_gem =
          remote_gemspecs.select  { |spec| spec.name == l_name }.
                          sort_by { |spec| spec.version }.
                          last
        if highest_remote_gem and l_spec.version < highest_remote_gem.version
          result << l_name
        end
      end
      result
    end
  end

  ####################################################################
  class CleanupCommand < Command
    def initialize
      super(
        'cleanup',
        'Clean up old versions of installed gems in the local repository',
        {
          :force => false, 
          :test => false, 
          :install_dir => Gem.dir
        })
      add_option('-d', '--dryrun', "") do |value, options|
        options[:dryrun] = true
      end
    end
    
    def defaults_str
      "--no-dryrun"
    end

    def arguments
      "GEMNAME(s)   name of gem(s) to cleanup"
    end

    def execute
      say "Cleaning up installed gems..."
      srcindex = Gem::SourceIndex.from_installed_gems
      primary_gems = {}
      srcindex.each do |name, spec|
        if primary_gems[spec.name].nil? or primary_gems[spec.name].version < spec.version
          primary_gems[spec.name] = spec
        end
      end
      gems_to_cleanup = []
      if ! options[:args].empty?
        options[:args].each do |gem_name|
          specs = Gem.cache.search(/^#{gem_name}$/i)
          specs.each do |spec|
            gems_to_cleanup << spec
          end
        end
      else
        srcindex.each do |name, spec|
            gems_to_cleanup << spec
        end
      end
      gems_to_cleanup = gems_to_cleanup.select { |spec|
        primary_gems[spec.name].version != spec.version
      }
      uninstall_command = command_manager['uninstall']
      deplist = DependencyList.new
      gems_to_cleanup.uniq.each do |spec| deplist.add(spec) end
      deplist.dependency_order.each do |spec|
        if options[:dryrun]
          say "Dry Run Mode: Would uninstall #{spec.full_name}"
        else
          say "Attempting uninstall on #{spec.full_name}"
          options[:args] = [spec.name]
          options[:version] = "= #{spec.version}"
          options[:executables] = true
          uninstall_command.merge_options(options)
          begin
            uninstall_command.execute
          rescue Gem::DependencyRemovalException => ex
            say "Unable to uninstall #{spec.full_name} ... continuing with remaining gems"
          end
        end
      end
      say "Clean Up Complete"
    end
  end
  
  ####################################################################
  class PristineCommand < Command
    include VersionOption
    include CommandAids
    def initialize
      super('pristine',
        'Restores gem directories to pristine condition from files located in the gem cache',
        {
          :version => "> 0.0.0"
        })
      add_option('--all',
        'Restore all installed gems to pristine', 'condition'
        ) do |value, options|
        options[:all] = value
      end
      add_version_option('restore to', 'pristine condition')
    end

    def defaults_str
      "--all"
    end

    def usage
      "#{program_name} [args]"
    end

    def arguments
      "GEMNAME          The gem to restore to pristine condition (unless --all)"
    end

    def execute
      say "Restoring gem(s) to pristine condition..."
      if options[:all]
        all_gems = true
        specs = Gem::SourceIndex.from_installed_gems.collect do |name, spec|
          spec
        end
      else
        all_gems = false
        gem_name = get_one_gem_name
        specs = Gem::SourceIndex.from_installed_gems.search(gem_name, options[:version])
      end

      if specs.empty?
        fail "Failed to find gem #{gem_name} #{options[:version]} to restore to pristine condition"
      end
      install_dir = Gem.dir # TODO use installer option
      raise Gem::FilePermissionError.new(install_dir) unless File.writable?(install_dir)

      gems_were_pristine = true

      specs.each do |spec|
        installer = Gem::Installer.new nil, :wrappers => true # HACK ugly TODO use installer option

        gem_file = File.join(install_dir, "cache", "#{spec.full_name}.gem")
        security_policy = nil # TODO use installer option
        format = Gem::Format.from_file_by_path(gem_file, security_policy)
        target_directory = File.join(install_dir, "gems", format.spec.full_name).untaint
        pristine_files = format.file_entries.collect {|data| data[0]["path"]}
        file_map = {}
        format.file_entries.each {|entry, file_data| file_map[entry["path"]] = file_data}
        require 'fileutils'

        Dir.chdir target_directory do
          deployed_files = Dir.glob(File.join("**", "*")) +
                           Dir.glob(File.join("**", ".*"))
          to_redeploy = (pristine_files - deployed_files).collect {|path| path.untaint}
          if to_redeploy.length > 0
            gems_were_pristine = false
            say "Restoring #{to_redeploy.length} file#{to_redeploy.length == 1 ? "" : "s"} to #{spec.full_name}..."
            to_redeploy.each do |path|
              say "  #{path}"
              FileUtils.mkdir_p File.dirname(path)
              File.open(path, "wb") do |out|
                out.write file_map[path]
              end
            end
          end
        end

        installer.generate_bin spec, install_dir
      end

      say "Rebuilt all bin stubs"

      if gems_were_pristine
        if all_gems
          say "All installed gem files are already in pristine condition"
        else
          say "#{specs[0].full_name} is already in pristine condition"
        end
      else
        if all_gems
          say "All installed gem files restored to pristine condition"
        else
          say "#{specs[0].full_name} restored to pristine condition"
        end
      end
    end
  end

  ####################################################################
  class RDocCommand < Command
    include VersionOption
    include CommandAids

    def initialize
      super('rdoc',
        'Generates RDoc for pre-installed gems',
        {
          :version => "> 0.0.0",
          :include_rdoc => true,
          :include_ri => true,
        })
      add_option('--all',
                 'Generate RDoc/RI documentation for all',
                 'installed gems') do |value, options|
        options[:all] = value
      end
      add_option('--[no-]rdoc', 
        'Include RDoc generated documents') do
        |value, options|
        options[:include_rdoc] = value
      end
      add_option('--[no-]ri', 
        'Include RI generated documents'
        ) do |value, options|
        options[:include_ri] = value
      end
      add_version_option('rdoc')
    end

    def defaults_str
      "--version '> 0.0.0' --rdoc --ri"
    end

    def usage
      "#{program_name} [args]"
    end

    def arguments
      "GEMNAME          The gem to generate RDoc for (unless --all)"
    end

    def execute
      if options[:all]
        specs = Gem::SourceIndex.from_installed_gems.collect { |name, spec|
          spec
        }
      else
        gem_name = get_one_gem_name
        specs = Gem::SourceIndex.from_installed_gems.search(
          gem_name, options[:version])
      end

      if specs.empty?
        fail "Failed to find gem #{gem_name} to generate RDoc for #{options[:version]}"
      end
      if options[:include_ri]
        specs.each do |spec|
          Gem::DocManager.new(spec).generate_ri
        end
      end
      if options[:include_rdoc]
        specs.each do |spec|
          Gem::DocManager.new(spec).generate_rdoc
        end
      end

      true
    end
  end

  ####################################################################
  class EnvironmentCommand < Command
    include CommandAids

    def initialize
      super('environment', 'Display information about the RubyGems environment')
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
        require 'sources'
        out << Gem.sources.join("\n") << "\n"
      elsif arg
        fail Gem::CommandLineError, "Unknown enviroment option [#{arg}]"
      else
        out = "RubyGems Environment:\n"
        out << "  - VERSION: #{Gem::RubyGemsVersion} (#{Gem::RubyGemsPackageVersion})\n"
        out << "  - INSTALLATION DIRECTORY: #{Gem.dir}\n"
        out << "  - GEM PATH:\n"
        Gem.path.collect { |p| out << "     - #{p}\n" }
        out << "  - REMOTE SOURCES:\n"
        require 'sources'
        Gem.sources.collect do |s|
          out << "     - #{s}\n"
        end
      end
      say out
      true
    end
  end

  ####################################################################
  class SpecificationCommand < Command
    include VersionOption
    include LocalRemoteOptions
    include CommandAids
    
    def initialize
      super('specification', 'Display gem specification (in yaml)',
            {:domain=>:local, :version=>"> 0.0.0"})
      add_version_option('examine')
      add_local_remote_options
      add_option('--all', 'Output specifications for all versions of',
                 'the gem') do |value, options|
        options[:all] = true
      end
    end

    def defaults_str
      "--local --version '(latest)'"
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
        gem_specs = Gem::SourceIndex.from_installed_gems.search(gem, options[:version])
        unless gem_specs.empty?
          require 'yaml'
          output = lambda { |spec| say spec.to_yaml; say "\n" }
          if options[:all]
            gem_specs.each(&output)
          else
            spec = gem_specs.sort_by { |spec| spec.version }.last
            output[spec]
          end
        else
          alert_error "Unknown gem #{gem}"
        end
      end
      
      if remote?
        say "(Remote 'info' operation is not yet implemented.)"
        # NOTE: when we do implement remote info, make sure we don't
        # duplicate huge swabs of local data.  If it's the same, just
        # say it's the same.
      end
    end
  end
  
  ####################################################################
  class UnpackCommand < Command
    include VersionOption
    include CommandAids

    def initialize
      super(
        'unpack',
        'Unpack an installed gem to the current directory',
        { :version => '> 0' }
      )
      add_version_option('unpack')
    end

    def defaults_str
      "--version '> 0'"
    end

    def usage
      "#{program_name} GEMNAME"
    end

    def arguments
      "GEMNAME       Name of the gem to unpack"
    end

    # TODO: allow, e.g., 'gem unpack rake-0.3.1'.  Find a general
    # solution for this, so that it works for uninstall as well.  (And
    # check other commands at the same time.)
    def execute
      gemname = get_one_gem_name
      path = get_path(gemname, options[:version])
      if path
        require 'fileutils'
        target_dir = File.basename(path).sub(/\.gem$/, '')
        FileUtils.mkdir_p target_dir
        Installer.new(path).unpack(File.expand_path(target_dir))
        say "Unpacked gem: '#{target_dir}'"
      else
        alert_error "Gem '#{gemname}' not installed."
      end
    end

    # Return the full path to the cached gem file matching the given
    # name and version requirement.  Returns 'nil' if no match.
    # Example:
    #
    #  get_path('rake', '> 0.4')   # -> '/usr/lib/ruby/gems/1.8/cache/rake-0.4.2.gem'
    #  get_path('rake', '< 0.1')   # -> nil
    #  get_path('rak')             # -> nil (exact name required)
    #
    # TODO: This should be refactored so that it's a general service.
    # I don't think any of our existing classes are the right place
    # though.  Just maybe 'Cache'?
    #
    # TODO: It just uses Gem.dir for now.  What's an easy way to get
    # the list of source directories?
    #
    def get_path(gemname, version_req)
      return gemname if gemname =~ /\.gem$/i
      specs = SourceIndex.from_installed_gems.search(gemname, version_req)
      selected = specs.sort_by { |s| s.version }.last
      return nil if selected.nil?
      # We expect to find (basename).gem in the 'cache' directory.
      # Furthermore, the name match must be exact (ignoring case).
      if gemname =~ /^#{selected.name}$/i
        filename = selected.full_name + '.gem'
        return File.join(Gem.dir, 'cache', filename)
      else
        return nil
      end
    end
  end
  
  ####################################################################
  class HelpCommand < Command
    include CommandAids

    def initialize
      super('help', "Provide help on the 'gem' command")
    end

    def usage
      "#{program_name} ARGUMENT"
    end

    def arguments
      args = <<-EOF
        commands      List all 'gem' commands
        examples      Show examples of 'gem' usage
        <command>     Show specific help for <command>
      EOF
      return args.gsub(/^\s+/, '')
    end

    def execute
      arg = options[:args][0]
      if begins?("commands", arg)
        out = []
        out << "GEM commands are:"
        out << nil

        margin_width = 4
        desc_width = command_manager.command_names.collect {|n| n.size}.max + 4
        summary_width = 80 - margin_width - desc_width
        wrap_indent = ' ' * (margin_width + desc_width)
        format = "#{' ' * margin_width}%-#{desc_width}s%s"

        command_manager.command_names.each do |cmd_name|
          summary = command_manager[cmd_name].summary
          summary = wrap(summary, summary_width).split "\n"
          out << sprintf(format, cmd_name, summary.shift)
          until summary.empty? do
            out << "#{wrap_indent}#{summary.shift}"
          end
        end

        out << nil
        out << "For help on a particular command, use 'gem help COMMAND'."
        out << nil
        out << "Commands may be abbreviated, so long as they are unambiguous."
        out << "e.g. 'gem i rake' is short for 'gem install rake'."

        say out.join("\n")

      elsif begins?("options", arg)
        say Gem::HELP
      elsif begins?("examples", arg)
        say Gem::EXAMPLES
      elsif options[:help]
        command = command_manager[options[:help]]
        if command
          # help with provided command
          command.invoke("--help")
        else
          alert_error "Unknown command #{options[:help]}.  Try 'gem help commands'"
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
  end

  ####################################################################
  class ContentsCommand < Command
    include CommandAids
    include VersionOption
    def initialize
      super(
        'contents',
        'Display the contents of the installed gems',
        { :list => true, :specdirs => [] })

      add_version_option('contents')

      add_option("-l","--list",'List the files inside a Gem') do |v,o|
        o[:list] = true
      end
      
      add_option('-s','--spec-dir a,b,c', Array, "Search for gems under specific paths") do |v,o|
        o[:specdirs] = v
      end
      
      add_option('-V','--verbose','Be verbose when showing status') do |v,o|
        o[:verbose] = v
      end
    end

    def execute(io=STDOUT)
      if options[:list]
        version = options[:version] || "> 0.0.0"
        gem = get_one_gem_name
        
        s = options[:specdirs].map do |i|
          [i, File.join(i,"specifications")]
        end.flatten
        
        if s.empty?
          s = Gem::SourceIndex.installed_spec_directories
          path_kind = "default gem paths"
          system = true
        else
          path_kind = "specified path"
          system = false
        end

        si = Gem::SourceIndex.from_gems_in(*s)

        gem_spec = si.search(gem, version).last
        unless gem_spec
          io.puts "Unable to find gem '#{gem}' in #{path_kind}"
          if options[:verbose]
            io.puts "\nDirectories searched:"
            s.each do |p|
              io.puts p
            end
          end
          return
        end
        # show the list of files.
        gem_spec.files.each do |f|
          io.puts File.join(gem_spec.full_gem_path, f)
        end
      end
    end
  end
  
end # module

######################################################################
# Documentation Constants
#
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
    }.gsub(/^    /, "")

  EXAMPLES = %{
    Some examples of 'gem' usage.

    * Install 'rake', either from local directory or remote server:
    
        gem install rake

    * Install 'rake', only from remote server:

        gem install rake --remote

    * Install 'rake' from remote server, and run unit tests,
      and generate RDocs:

        gem install --remote rake --test --rdoc --ri

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
