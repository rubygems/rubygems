require 'pathname'
require 'rbconfig'
require 'rubygems/format'
require 'rubygems/dependency_list'

module Gem

  class DependencyRemovalException < Gem::Exception; end

  ##
  # The installer class processes RubyGem .gem files and installs the
  # files contained in the .gem into the Gem.path.
  #
  class Installer
  
    include UserInteraction
  
    ##
    # Constructs an Installer instance
    #
    # gem:: [String] The file name of the gem
    #
    def initialize(gem, options)
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
    # force:: [default = false] if false will fail if a required Gem is not installed,
    #         or if the Ruby version is too low for the gem
    # install_dir:: [default = Gem.dir] directory that Gem is to be installed in
    # install_stub:: [default = false] causes the installation of a library stub in the +site_ruby+ directory
    #
    # return:: [Gem::Specification] The specification for the newly installed Gem.
    #
    def install(force=false, install_dir=Gem.dir, install_stub=false)
      require 'fileutils'
      format = Gem::Format.from_file_by_path(@gem)
      unless force
        spec = format.spec
        # Check the Ruby version.
        if (rrv = spec.required_ruby_version)
          unless rrv.satisfied_by?(Gem::Version.new(RUBY_VERSION))
            raise "#{spec.name} requires Ruby version #{rrv}"
          end
        end
        # Check the dependent gems.
	unless @options[:ignore_dependencies]
	  spec.dependencies.each do |dep_gem|
	    # TODO: Does this take account of *versions*?
	    require_gem_with_options(dep_gem, [], :auto_require=>false)
	  end
	end
      end
      
      raise Gem::FilePermissionError.new(install_dir) unless File.writable?(install_dir)

      # Build spec dir.
      directory = File.join(install_dir, "gems", format.spec.full_name)
      FileUtils.mkdir_p directory

      extract_files(directory, format)
      generate_bin_scripts(format.spec, install_dir)
      #generate_library_stubs(format.spec) if install_stub
      build_extensions(directory, format.spec)
      
      # Build spec/cache/doc dir.
      build_support_directories(install_dir)
      
      # Write the spec and cache files.
      write_spec(format.spec, File.join(install_dir, "specifications"))
      unless(File.exist?(File.join(File.join(install_dir, "cache"), @gem.split(/\//).pop))) 
        FileUtils.cp(@gem, File.join(install_dir, "cache"))
      end

      format.spec.loaded_from = File.join(install_dir, 'specifications', format.spec.full_name+".gemspec")
      return format.spec
    end

    # 
    # Unpacks the gem into the given directory.
    #
    def unpack(directory)
      format = Gem::Format.from_file_by_path(@gem)
      extract_files(directory, format)
    end

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
      File.open(File.join(spec_path, spec.full_name+".gemspec"), "w") do |file|
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
          file.puts "@ruby \"#{File.join(bindir,filename)}\" %*"
        end
      end
    end

    ##
    # Creates the scripts to run the applications in the gem.
    #
    def generate_bin_scripts(spec, install_dir=Gem.dir)
      if spec.executables && ! spec.executables.empty?
        bindir = if(install_dir == Gem.default_dir)
	  Config::CONFIG['bindir'] 
	else
	  File.join(install_dir, "bin")
	end
        Dir.mkdir(bindir) unless File.exist?(bindir)
        raise Gem::FilePermissionError.new(bindir) unless File.writable?(bindir)
        spec.executables.each do |filename|
          File.open(File.join(bindir, File.basename(filename)), "w", 0755) do |file|
            file.print(app_script_text(spec, install_dir, filename))
          end
          generate_windows_script(bindir, filename)
        end
      end
    end

    def shebang(spec, install_dir, file_name)
      first_line = ""
      File.open(
	File.join(install_dir,
	  "gems",
	  spec.full_name,
	  spec.bindir,
	  file_name), "rb") do |file|
        first_line = file.readlines("\n").first 
      end
      if first_line =~ /^#!/ then
        first_line.sub(/\A\#!\s*\S*ruby\S*/, "#!" + File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])) #Thanks RPA
      else
        "\#!#{File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])}"
      end
    end

    ##
    # Returns the text for an application file.
    #
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
if ARGV.size > 0 && ARGV[0][0]==95 && ARGV[0][-1]==95
  if Gem::Version.correct?(ARGV[0][1..-2])
    version = ARGV[0][1..-2] 
    ARGV.shift
  end
end
require_gem '#{spec.name}', version
load '#{filename}'  
TEXT
      text
    end

    ##
    # Creates a file in the site_ruby directory that acts as a stub
    # for the gem.  Thus, if 'package' is installed as a gem, the user
    # can just type <tt>require 'package'</tt> and the gem (latest
    # version) will be loaded.  This is like a backwards compatibility
    # so that gems and non-gems can interact.
    #
    # Which files are stubified?  Those included in the gem's
    # 'autorequire' and 'library_stubs' attributes.
    #
    def generate_library_stubs(spec)
      LibraryStubs.new(spec).generate
    end

    def build_extensions(directory, spec)
      return unless spec.extensions.size > 0
      say "Building native extensions.  This could take a while..."
      start_dir = Dir.pwd
      dest_path = File.join(directory, spec.require_paths[0])
      spec.extensions.each do |extension|
        Dir.chdir File.join(directory, File.dirname(extension))
        results = ["ruby #{File.basename(extension)} #{ARGV.join(" ")}"]
        results << `ruby #{File.basename(extension)} #{ARGV.join(" ")}`
        if File.exist?('Makefile')
          mf = File.read('Makefile')
          mf = mf.gsub(/^RUBYARCHDIR\s*=\s*\$.*/, "RUBYARCHDIR = #{dest_path}")
          mf = mf.gsub(/^RUBYLIBDIR\s*=\s*\$.*/, "RUBYLIBDIR = #{dest_path}")
          File.open('Makefile', 'wb') {|f| f.print mf}
          make_program = ENV['make']
          unless make_program
            make_program = (/mswin/ =~ RUBY_PLATFORM) ? 'nmake' : 'make'
          end
          results << "#{make_program}"
          results << `#{make_program}`
          results << "#{make_program} install"
          results << `#{make_program} install`
          say results.join("\n")
        else
          File.open(File.join(Dir.pwd, 'gem_make.out'), 'wb') {|f| f.puts results.join("\n")}
          raise "ERROR: Failed to build gem native extension.\nGem files will remain installed in #{directory} for inspection.\n  #{results.join('\n')}\n\nResults logged to #{File.join(Dir.pwd, 'gem_make.out')}"
        end
        File.open('gem_make.out', 'wb') {|f| f.puts results.join("\n")}
      end
      Dir.chdir start_dir
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
      require 'fileutils'
      wd = Dir.getwd
      Dir.chdir directory do
        format.file_entries.each do |entry, file_data|
          path = entry['path']
          FileUtils.mkdir_p File.dirname(path)
          File.open(path, "wb") do |out|
            out.write file_data
          end
        end
      end
    end
  end  # class Installer


  #
  # This class represents a single library stub, which is
  # characterised by a
  #
  class LibraryStub
    SITELIBDIR = Pathname.new(Config::CONFIG['sitelibdir'])

    #
    # The 'autorequire' attribute in a gemspec is a special case: it
    # represents a require target, not a relative path.  We therefore
    # offer this method of creating a library stub for the autorequire
    # file.
    #
    # If the given spec doesn't have an 'autorequire' value, we return
    # +nil+.
    #
    def self.from_autorequire(gemspec, require_paths)
      require_target = gemspec.autorequire
      return nil if require_target.nil?
      gem_relpath = find_gem_relpath(require_paths, require_target, gemspec)
      LibraryStub.new(gemspec.name, require_paths, gem_relpath, true)
    end

    #
    # require_paths::
    #   ([Pathname]) The require paths in the gemspec.
    # gem_relpath::
    #   (String) The path to the library file, relative to the root of the gem.
    # autorequire::
    #   (Boolean) Whether this stub represents the gem's autorequire file.
    #
    def initialize(gem_name, require_paths, gem_relpath, autorequire=false)
      @gem_name       = gem_name
      @lib_relpath    = find_lib_relpath(require_paths, gem_relpath)
      @require_target = @lib_relpath.to_s.sub(/\.rb\Z/, '')
      @stub_path      = SITELIBDIR.join(@lib_relpath)
      @autorequire    = autorequire
    end

    #
    # The powerhouse of the class.  No exceptions should result from
    # calling this.
    #
    def generate
      if @stub_path.exist?
        # The stub path is inhabited by a file.  If it's a gem stub,
        # we'll overwrite it (just to be sure).  If it's a genuine
        # library, we'll leave it alone and issue a warning.
        unless library_stub?(@stub_path)
          alert_warning(
            ["Library file '#{target_path}'",
             "already exists; not overwriting.  If you want to force a",
             "library stub, delete the file and reinstall."].join("\n")
          )
          return
        end
      end

      unless @stub_path.dirname.exist?
        @stub_path.dirname.mkpath
      end
      @stub_path.open('w', 0644) do |io|
        io.write(library_stub_content())
      end
    end

    # Two LibraryStub objects are equal if they have the same gem name
    # and relative (gem) path.
    def ==(other)
      LibraryStub === other and @gem_name == other.gem_name and
        @gem_relpath == other.gem_relpath
    end

   private

    #
    # require_paths::
    #   ([Pathname]) The require paths in the gemspec.
    # require_target::
    #   (String) The subject of an intended 'require' statement.
    # gemspec::
    #   (Gem::Specification) 
    #
    # The aim of this method is to resolve the require_target into a
    # path relative to the root of the gem.  We try each require path
    # in turn, and see if the require target exists under that
    # directory.
    #
    # If no match is found, we return +nil+. 
    #
    def self.find_gem_relpath(require_paths, require_target, gemspec)
      require_target << '.rb' unless require_target =~ /\.rb\Z/
      gem_files = gemspec.files.map { |path| Pathname.new(path).cleanpath }
      require_paths.each do |require_path|
        possible_lib_path = require_path.join(require_target)
        if gem_files.include?(possible_lib_path)
          return possible_lib_path.to_s
        end
      end
      nil  # If we get this far, there was no match.
    end

    #
    # require_paths::
    #   ([Pathname]) The require paths in the gemspec.
    # gem_relpath::
    #   (String) The path to the library file, relative to the root of the gem.
    #
    # Returns: the path (Pathname) to the same file, relative to the
    # gem's library path (typically 'lib').  Thus
    # 'lib/rake/rdoctask.rb' becomes 'rake/rdoctask.rb'.  The gemspec
    # may contain several library paths, though that would be unusual,
    # so we must deal with that possibility here.
    #
    # If there is no such relative path, we return +nil+. 
    #
    def find_lib_relpath(require_paths, gem_relpath)
      require_paths.each do |require_path|
        begin
          return Pathname.new(gem_relpath).relative_path_from(require_path)
        rescue ArgumentError
          next
        end
        nil  # If we get this far, there was no match.
      end
    end

    # Returns a string suitable for placing in a stub file.
    def library_stub_content
      content = %{
        #
        # This file was generated by RubyGems.
        #
        # The library '#{@gem_name}' is installed as part of a gem, and
        # this file is here so you can 'require' it easily (i.e.
        # without having to know it's a gem).
        #
        # gem: #{@gem_name}
        # stub: #{@lib_relpath} 
        #
 
        require 'rubygems'
        $".delete('#{@lib_relpath}') # " emacs wart
        require_gem '#{@gem_name}'
      }.gsub(/^[ \t]+/, '')
      unless @autorequire
        content << %{require '#{@require_target}'\n}
      end
      content << %{
        # (end of stub)
      }.gsub(/^[ \t]+/, '')
    end

    # Returns true iff the contents of the given _path_ (a Pathname)
    # appear to be a RubyGems library stub.
    def library_stub?(path)
      lines = path.readlines
      lines.grep(/^# This file was generated by RubyGems/) and
        lines.grep(/is installed as part of a gem, and/)
    end

  end  # class LibraryStub
  
  
  #
  # This class contains the logic to generate all library stubs,
  # including the autorequire, for a single gemspec.
  #
  #   LibraryStubs.new(gemspec).generate 
  #
  class LibraryStubs
    SITELIBDIR = Pathname.new(Config::CONFIG['sitelibdir'])

    def initialize(spec)
      @spec = spec
    end

    def generate
      require_paths = @spec.require_paths.map { |p| Pathname.new(p) }
      stubs = @spec.library_stubs.map {
        |stub| LibraryStub.new(@spec.name, require_paths, stub)
      }
      stubs << LibraryStub.from_autorequire(@spec, require_paths)
      stubs = stubs.compact.uniq
      unless stubs.empty?
        if FileTest.writable?(SITELIBDIR)
          stubs.each do |stub| stub.generate end
        else
          alert_warning(
            ["Can't install library stub for gem '#{spec.name}'",
             "(Don't have write permissions on '#{sitelibdir}' directory.)"].join("\n")
           )
        end
      end
    end
  end  # class LibraryStubs

  
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
    # Application and library stubs are removed according to what is
    # still installed.
    #
    # XXX: Application stubs refer to specific gem versions, which
    # means things may get inconsistent after an uninstall
    # (i.e. referring to a version that no longer exists).
    #
    def uninstall
      require 'fileutils'
      Gem.source_index.refresh!
      list = Gem.source_index.search(@gem, @version)
      if list.size == 0 
        raise "Unknown RubyGem: #{@gem} (#{@version})"
      elsif list.size > 1 && @force_all
	remove_all(list.dup) 
	remove_executables(list.last)
      elsif list.size > 1 
        say 
        gem_names = list.collect {|gem| gem.full_name} + ["All versions"]
        gem_name, index =
	  choose_from_list("Select RubyGem to uninstall:", gem_names)
        if index == list.size
          remove_all(list.dup) 
          remove_executables(list.last)
        elsif index >= 0 && index < list.size
          remove(list[index], list)
          remove_executables(list[index])
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
        raise Gem::FilePermissionError.new(Config::CONFIG['bindir']) unless
	  File.writable?(Config::CONFIG['bindir'])
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
	  true)
        unless answer
          say "Executables and scripts will remain installed."
          return
        else
          bindir = Config::CONFIG['bindir']
          gemspec.executables.each do |exe_name|
            say "Removing #{exe_name}"
            File.unlink(File.join(bindir, exe_name)) rescue nil
            File.unlink(File.join(bindir, exe_name + ".cmd")) rescue nil
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
    # Remove application and library stub files.  These are detected
    # by the line
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
      remove_lib_stub(spec, other_specs)
    end

    def remove_app_stubs(spec, other_specs)
      # App stubs are tricky, because each version of an app gem could
      # install different applications.  We need to make sure that
      # what we delete isn't needed by any remaining versions of the
      # gem.
      #
      # There's extra trickiness, too, because app stubs 'require_gem'
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

    def remove_lib_stub(spec, other_specs)
      # Library stubs are a bit easier than application stubs.  They
      # do not refer to a specific version; they just load the latest
      # version of the library available as a gem.  The only corner
      # case is that different versions of the same gem may have
      # different autorequire settings, which means they will have
      # different library stubs.
      #
      # I suppose our policy should be: when you uninstall a library,
      # make sure all the remaining versions of that gem are still
      # supported by stubs.  Of course, the user may have expressed a
      # preference in the past not to have library stubs installed.
      #
      # Mixing the segregated world of gem installations with the
      # global namespace of the site_ruby directory certainly brings
      # some tough issues.
    end
  end  # class Uninstaller

end  # module Gem
