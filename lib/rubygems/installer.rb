#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'fileutils'
require 'pathname'
require 'rbconfig'
require 'rubygems/format'
require 'rubygems/dependency_list'

class Gem::InstallError < Gem::Exception; end

module Gem

  class DependencyRemovalException < Gem::Exception; end

  ##
  # The installer class processes RubyGem .gem files and installs the
  # files contained in the .gem into the Gem.path.
  #
  class Installer

    ##
    # Raised when there is an error while building extensions.
    #
    class ExtensionBuildError < Gem::InstallError; end

    include UserInteraction

    ##
    # Constructs an Installer instance
    #
    # gem:: [String] The file name of the gem
    #
    def initialize(gem, options={})
      @gem = gem
      @options = options
    end

    ##
    # Installs the gem in the Gem.path.  This will fail (unless
    # force=true) if a Gem has a requirement on another Gem that is
    # not installed.  The installation will install in the following
    # structure:
    #
    #  Gem.path/
    #      specifications/<gem-version>.gemspec #=> the extracted YAML gemspec
    #      gems/<gem-version>/... #=> the extracted Gem files
    #      cache/<gem-version>.gem #=> a cached copy of the installed Gem
    #
    # force:: [default = false] if false will fail if a required Gem is not
    #         installed, or if the Ruby version is too low for the gem
    # install_dir:: [default = Gem.dir] directory that Gem is to be installed in
    #
    # return:: [Gem::Specification] The specification for the newly installed
    #          Gem.
    #
    def install(force=false, install_dir=Gem.dir, ignore_this_parameter=false)
      # if we're forcing the install, then disable security, _unless_
      # the security policy says that we only install singed gems
      # (this includes Gem::Security::HighSecurity)
      security_policy = @options[:security_policy]
      security_policy = nil if force && security_policy && security_policy.only_signed != true

      begin
        format = Gem::Format.from_file_by_path @gem, security_policy
      rescue Gem::Package::FormatError
        raise Gem::InstallError, "invalid gem format for #{@gem}"
      end
      unless force
        spec = format.spec
        # Check the Ruby version.
        if (rrv = spec.required_ruby_version)
          unless rrv.satisfied_by?(Gem::Version.new(RUBY_VERSION))
            raise Gem::InstallError, "#{spec.name} requires Ruby version #{rrv}"
          end
        end
        unless @options[:ignore_dependencies]
          spec.dependencies.each do |dep_gem|
            ensure_dependency!(spec, dep_gem)
          end
        end
      end

      raise Gem::FilePermissionError.new(Pathname.new(install_dir).expand_path) unless File.writable?(install_dir)

      # Build spec dir.
      @directory = File.join(install_dir, "gems", format.spec.full_name).untaint
      FileUtils.mkdir_p @directory

      extract_files(@directory, format)
      generate_bin(format.spec, install_dir)
      build_extensions(@directory, format.spec)

      # Build spec/cache/doc dir.
      build_support_directories(install_dir)

      # Write the spec and cache files.
      write_spec(format.spec, File.join(install_dir, "specifications"))
      unless File.exist? File.join(install_dir, "cache", @gem.split(/\//).pop)
        FileUtils.cp @gem, File.join(install_dir, "cache")
      end

      puts format.spec.post_install_message unless format.spec.post_install_message.nil?

      format.spec.loaded_from = File.join(install_dir, 'specifications', format.spec.full_name+".gemspec")
      return format.spec
    rescue Zlib::GzipFile::Error
      raise InstallError, "gzip error installing #{@gem}"
    end

    ##
    # Ensure that the dependency is satisfied by the current
    # installation of gem.  If it is not, then fail (i.e. throw and
    # exception).
    #
    # spec       :: Gem::Specification
    # dependency :: Gem::Dependency
    def ensure_dependency!(spec, dependency)
      raise Gem::InstallError, "#{spec.name} requires #{dependency.name} #{dependency.version_requirements} " unless
        installation_satisfies_dependency?(dependency)
    end

    ##
    # True if the current installed gems satisfy the given dependency.
    #
    # dependency :: Gem::Dependency
    def installation_satisfies_dependency?(dependency)
      current_index = SourceIndex.from_installed_gems
      current_index.find_name(dependency.name, dependency.version_requirements).size > 0
    end

    ##
    # Unpacks the gem into the given directory.
    #
    def unpack(directory)
      format = Gem::Format.from_file_by_path(@gem, @options[:security_policy])
      extract_files(directory, format)
    end

    ##
    # Given a root gem directory, build supporting directories for gem
    # if they do not already exist
    def build_support_directories(install_dir)
       unless File.exist? File.join(install_dir, "specifications")
         FileUtils.mkdir_p File.join(install_dir, "specifications")
       end
       unless File.exist? File.join(install_dir, "cache")
         FileUtils.mkdir_p File.join(install_dir, "cache")
       end
       unless File.exist? File.join(install_dir, "doc")
         FileUtils.mkdir_p File.join(install_dir, "doc")
       end
    end

    ##
    # Writes the .gemspec specification (in Ruby) to the supplied
    # spec_path.
    #
    # spec:: [Gem::Specification] The Gem specification to output
    # spec_path:: [String] The location (path) to write the gemspec to
    #
    def write_spec(spec, spec_path)
      rubycode = spec.to_ruby
      file_name = File.join(spec_path, spec.full_name+".gemspec").untaint
      File.open(file_name, "w") do |file|
        file.puts rubycode
      end
    end

    ##
    # Creates windows .cmd files for easy running of commands
    #
    def generate_windows_script(bindir, filename)
      if Config::CONFIG["arch"] =~ /dos|win32/i
        script_name = filename + ".cmd"
        File.open(File.join(bindir, File.basename(script_name)), "w") do |file|
          file.puts "@#{Gem.ruby} \"#{File.join(bindir,filename)}\" %*"
        end
      end
    end

    def generate_bin(spec, install_dir=Gem.dir)
      return unless spec.executables && ! spec.executables.empty?
      
      # If the user has asked for the gem to be installed in
      # a directory that is the system gem directory, then
      # use the system bin directory, else create (or use) a
      # new bin dir under the install_dir.
      bindir = Gem.bindir(install_dir)

      Dir.mkdir bindir unless File.exist? bindir
      raise Gem::FilePermissionError.new(bindir) unless File.writable?(bindir)

      spec.executables.each do |filename|
        if @options[:wrappers] then
          generate_bin_script spec, filename, bindir, install_dir
        else
          generate_bin_symlink spec, filename, bindir, install_dir
        end
      end
    end

    ##
    # Creates the scripts to run the applications in the gem.
    #
    def generate_bin_script(spec, filename, bindir, install_dir)
      File.open(File.join(bindir, File.basename(filename)), "w", 0755) do |file|
        file.print app_script_text(spec, install_dir, filename)
      end
      generate_windows_script bindir, filename
    end

    ##
    # Creates the symlinks to run the applications in the gem.  Moves
    # the symlink if the gem being installed has a newer version.
    #
    def generate_bin_symlink(spec, filename, bindir, install_dir)
      if Config::CONFIG["arch"] =~ /dos|win32/i then
        warn "Unable to use symlinks on win32, installing wrapper"
        generate_bin_script spec, filename, bindir, install_dir
        return
      end

      src = File.join @directory, 'bin', filename
      dst = File.join bindir, File.basename(filename)

      if File.exist? dst then
        if File.symlink? dst then
          link = File.readlink(dst).split File::SEPARATOR
          cur_version = Gem::Version.create(link[-3].sub(/^.*-/, ''))
          return if spec.version < cur_version
        end
        File.unlink dst
      end

      File.symlink src, dst
    end

    def shebang(spec, install_dir, bin_file_name)
      if @options[:env_shebang]
        shebang_env
      else
        shebang_default(spec, install_dir, bin_file_name)
      end
    end

    def shebang_default(spec, install_dir, bin_file_name)
      path = File.join(install_dir, "gems", spec.full_name, spec.bindir, bin_file_name)
      File.open(path, "rb") do |file|
        first_line = file.readlines("\n").first 
        path_to_ruby = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
        if first_line =~ /^#!/
          # Preserve extra words on shebang line, like "-w".  Thanks RPA.
          shebang = first_line.sub(/\A\#!\s*\S*ruby\S*/, "#!" + path_to_ruby)
        else
          # Create a plain shebang line.
          shebang = "#!" + path_to_ruby
        end
        return shebang.strip  # Avoid nasty ^M issues.
      end
    end

    def shebang_env
      return "#!/usr/bin/env ruby"
    end

    # Return the text for an application file.
    def app_script_text(spec, install_dir, filename)
      text = <<-TEXT
#{shebang(spec, install_dir, filename)}
#
# This file was generated by RubyGems.
#
# The application '#{spec.name}' is installed as part of a gem, and
# this file is here to facilitate running it. 
#

require 'rubygems'
version = "> 0"
if ARGV.first =~ /^_(.*)_$/ and Gem::Version.correct? $1 then
  version = $1
  ARGV.shift
end
gem '#{spec.name}', version
load '#{filename}'
TEXT
      text
    end

    def build_extensions(directory, spec)
      return unless spec.extensions.size > 0
      say "Building native extensions.  This could take a while..."
      start_dir = Dir.pwd
      dest_path = File.join(directory, spec.require_paths[0])
      ran_rake = false # only run rake once

      spec.extensions.each do |extension|
        break if ran_rake
        results = []

        case extension
        when /extconf/ then
          builder = ExtExtConfBuilder
        when /configure/ then
          builder = ExtConfigureBuilder
        when /rakefile/i, /mkrf_conf/i then
          builder = ExtRakeBuilder
          ran_rake = true
        else
          builder = nil
          results = ["No builder for extension '#{extension}'"]
        end

        begin
          Dir.chdir File.join(directory, File.dirname(extension))
          results = builder.build(extension, directory, dest_path, results)
        rescue => ex
          results = results.join "\n"

          File.open('gem_make.out', 'wb') { |f| f.puts results }

          message = <<-EOF
ERROR: Failed to build gem native extension.

#{results}

Gem files will remain installed in #{directory} for inspection.
Results logged to #{File.join(Dir.pwd, 'gem_make.out')}
          EOF

          raise ExtensionBuildError, message
        ensure
          Dir.chdir start_dir
        end
      end
    end

    ##
    # Reads the YAML file index and then extracts each file
    # into the supplied directory, building directories for the
    # extracted files as needed.
    #
    # directory:: [String] The root directory to extract files into
    # file:: [IO] The IO that contains the file data
    #
    def extract_files(directory, format)
      directory = expand_and_validate(directory)
      raise ArgumentError, "format required to extract from" if format.nil?
      
      format.file_entries.each do |entry, file_data|
        path = entry['path'].untaint
        if path =~ /\A\// then # for extra sanity
          raise Gem::InstallError,
                "attempt to install file into #{entry['path'].inspect}"
        end
        path = File.expand_path File.join(directory, path)
        if path !~ /\A#{Regexp.escape directory}/ then
          msg = "attempt to install file into %p under %p" %
                  [entry['path'], directory]
          raise Gem::InstallError, msg
        end
        FileUtils.mkdir_p File.dirname(path)
        File.open(path, "wb") do |out|
          out.write file_data
        end
      end
    end
    
    private
    def expand_and_validate(directory)
      directory = Pathname.new(directory).expand_path
      unless directory.absolute?      
        raise ArgumentError, "install directory %p not absolute" % directory
      end
      directory.to_str
    end
  end  # class Installer

  ##
  # The Uninstaller class uninstalls a Gem
  #
  class Uninstaller

    include UserInteraction

    ##
    # Constructs an Uninstaller instance
    #
    # gem:: [String] The Gem name to uninstall
    #
    def initialize(gem, options)
      @gem = gem
      @version = options[:version] || "> 0"
      @force_executables = options[:executables]
      @force_all = options[:all]
      @force_ignore = options[:ignore]
    end

    ##
    # Performs the uninstall of the Gem.  This removes the spec, the
    # Gem directory, and the cached .gem file,
    #
    # Application stubs are (or should be) removed according to what
    # is still installed.
    #
    # XXX: Application stubs refer to specific gem versions, which
    # means things may get inconsistent after an uninstall
    # (i.e. referring to a version that no longer exists).
    #
    def uninstall
      list = Gem.source_index.search(/^#{@gem}$/, @version)
      if list.empty?
        raise Gem::InstallError, "Unknown gem #{@gem}-#{@version}"
      elsif list.size > 1 && @force_all
        remove_all(list.dup) 
        remove_executables(list.last)
      elsif list.size > 1 
        say 
        gem_names = list.collect {|gem| gem.full_name} + ["All versions"]
        gem_name, index =
          choose_from_list("Select gem to uninstall:", gem_names)
        if index == list.size
          remove_all(list.dup) 
          remove_executables(list.last)
        elsif index >= 0 && index < list.size
          to_remove = list[index]
          remove(to_remove, list)
          remove_executables(to_remove)
        else
          say "Error: must enter a number [1-#{list.size+1}]"
        end
      else
        remove(list[0], list.dup)
        remove_executables(list.last)
      end
    end
    
    ##
    # Remove executables and batch files (windows only) for the gem as
    # it is being installed
    #
    # gemspec::[Specification] the gem whose executables need to be removed.
    #
    def remove_executables(gemspec)
      return if gemspec.nil?
      if(gemspec.executables.size > 0)
        raise Gem::FilePermissionError.new(Gem.bindir) unless
          File.writable?(Gem.bindir)
        list = Gem.source_index.search(gemspec.name).delete_if { |spec|
          spec.version == gemspec.version
        }
        executables = gemspec.executables.clone
        list.each do |spec|
          spec.executables.each do |exe_name|
            executables.delete(exe_name)
          end
        end
        return if executables.size == 0
        answer = @force_executables || ask_yes_no(
          "Remove executables and scripts for\n" +
          "'#{gemspec.executables.join(", ")}' in addition to the gem?",
          true) # " # appease ruby-mode - don't ask
        unless answer
          say "Executables and scripts will remain installed."
          return
        else
          gemspec.executables.each do |exe_name|
            say "Removing #{exe_name}"
            File.unlink File.join(Gem.bindir, exe_name) rescue nil
            File.unlink File.join(Gem.bindir, exe_name + ".cmd") rescue nil
          end
        end
      end
    end
    
    #
    # list:: the list of all gems to remove
    #
    # Warning: this method modifies the +list+ parameter.  Once it has
    # uninstalled a gem, it is removed from that list.
    #
    def remove_all(list)
      list.dup.each { |gem| remove(gem, list) }
    end

    #
    # spec:: the spec of the gem to be uninstalled
    # list:: the list of all such gems
    #
    # Warning: this method modifies the +list+ parameter.  Once it has
    # uninstalled a gem, it is removed from that list.
    #
    def remove(spec, list)
      if( ! ok_to_remove?(spec)) then
        raise DependencyRemovalException.new(
          "Uninstallation aborted due to dependent gem(s)")
      end
      raise Gem::FilePermissionError.new(spec.installation_path) unless
        File.writable?(spec.installation_path)
      FileUtils.rm_rf spec.full_gem_path
      FileUtils.rm_rf File.join(
        spec.installation_path,
        'specifications',
        "#{spec.full_name}.gemspec")
      FileUtils.rm_rf File.join(
        spec.installation_path,
        'cache',
        "#{spec.full_name}.gem")
      DocManager.new(spec).uninstall_doc
      #remove_stub_files(spec, list - [spec])
      say "Successfully uninstalled #{spec.name} version #{spec.version}"
      list.delete(spec)
    end

    def ok_to_remove?(spec)
      return true if @force_ignore
      srcindex= Gem::SourceIndex.from_installed_gems
      deplist = Gem::DependencyList.from_source_index(srcindex)
      deplist.ok_to_remove?(spec.full_name) ||
        ask_if_ok(spec)
    end

    def ask_if_ok(spec)
      msg = ['']
      msg << 'You have requested to uninstall the gem:'
      msg << "\t#{spec.full_name}"
      spec.dependent_gems.each do |gem,dep,satlist|
        msg <<
          ("#{gem.name}-#{gem.version} depends on " +
          "[#{dep.name} (#{dep.version_requirements})]")
      end
      msg << 'If you remove this gems, one or more dependencies will not be met.'
      msg << 'Continue with Uninstall?'
      return ask_yes_no(msg.join("\n"), true)
    end

    private

    ##
    # Remove application stub files.  These are detected by the line
    #   # This file was generated by RubyGems.
    #
    # spec:: the spec of the gem that is being uninstalled
    # other_specs:: any other installed specs for this gem
    #               (i.e. different versions)
    #
    # Both parameters are necessary to ensure that the correct files
    # are uninstalled.  It is assumed that +other_specs+ contains only
    # *installed* gems, except the one that's about to be uninstalled.
    #
    def remove_stub_files(spec, other_specs)
      remove_app_stubs(spec, other_specs)
    end

    def remove_app_stubs(spec, other_specs)
      # App stubs are tricky, because each version of an app gem could
      # install different applications.  We need to make sure that
      # what we delete isn't needed by any remaining versions of the
      # gem.
      #
      # There's extra trickiness, too, because app stubs 'gem'
      # a specific version of the gem.  If we uninstall the latest
      # gem, we should ensure that there is a sensible app stub(s)
      # installed after the removal of the current one.
      #
      # Perhaps the best way to approach this is:
      # * remove all application stubs for this gemspec
      # * regenerate the app stubs for the latest remaining version
      #    (you always want to have the latest version of an app,
      #    don't you?)
      #
      # The Installer class doesn't really support this approach very
      # well at the moment.
    end

  end  # class Uninstaller

  class ExtBuilder

    def self.class_name
      name =~ /Ext(.*)Builder/
      $1.downcase
    end

    def self.make(dest_path, results)
      unless File.exist? 'Makefile' then
        raise Gem::InstallError, "Makefile not found:\n\n#{results.join "\n"}" 
      end

      mf = File.read('Makefile')
      mf = mf.gsub(/^RUBYARCHDIR\s*=\s*\$[^$]*/, "RUBYARCHDIR = #{dest_path}")
      mf = mf.gsub(/^RUBYLIBDIR\s*=\s*\$[^$]*/, "RUBYLIBDIR = #{dest_path}")

      File.open('Makefile', 'wb') {|f| f.print mf}

      make_program = ENV['make']
      unless make_program then
        make_program = (/mswin/ =~ RUBY_PLATFORM) ? 'nmake' : 'make'
      end

      ['', ' install'].each do |target|
        cmd = "#{make_program}#{target}"
        results << cmd
        results << `#{cmd} #{redirector}`

        raise Gem::InstallError, "make#{target} failed:\n\n#{results}" unless
          $?.exitstatus.zero?
      end
    end

    def self.redirector
      '2>&1'
    end

    def self.run(command, results)
      results << command
      results << `#{command} #{redirector}`

      unless $?.exitstatus.zero? then
        raise Gem::InstallError, "#{class_name} failed:\n\n#{results.join "\n"}"
      end
    end

  end

  class ExtConfigureBuilder < ExtBuilder
    def self.build(extension, directory, dest_path, results)
      unless File.exist?('Makefile') then
        cmd = "sh ./configure --prefix=#{dest_path}"

        run cmd, results
      end

      make dest_path, results

      results
    end
  end

  class ExtExtConfBuilder < ExtBuilder
    def self.build(extension, directory, dest_path, results)
      cmd = "#{Gem.ruby} #{File.basename extension}"
      cmd << " #{ARGV.join " "}" unless ARGV.empty?

      run cmd, results

      make dest_path, results

      results
    end
  end

  class ExtRakeBuilder < ExtBuilder
    def ExtRakeBuilder.build(ext, directory, dest_path, results)
      cmd = ENV['rake'] || 'rake'
      cmd << " RUBYARCHDIR=#{dest_path} RUBYLIBDIR=#{dest_path} extension"

      run cmd, results

      results
    end
  end

end  # module Gem
