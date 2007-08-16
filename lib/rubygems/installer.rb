#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'fileutils'
require 'pathname'
require 'rbconfig'

require 'rubygems/format'
require 'rubygems/ext'

##
# The installer class processes RubyGem .gem files and installs the
# files contained in the .gem into the Gem.path.
#
class Gem::Installer

  ##
  # Raised when there is an error while building extensions.
  #
  class ExtensionBuildError < Gem::InstallError; end

  include Gem::UserInteraction

  ##
  # Constructs an Installer instance
  #
  # gem:: [String] The file name of the gem
  #
  def initialize(gem, options={})
    @gem = gem

    @env_shebang = options.delete :env_shebang
    @ignore_dependencies = options.delete :ignore_dependencies
    @security_policy = options.delete :security_policy
    @wrappers = options.delete :wrappers
  end

  ##
  # Installs the gem into +install_dir+ and returns a Gem::Specification for
  # the installed gem.  +force+ overrides all version checks and security
  # policy checks, except for a signed-gems-only policy.
  #
  # The installation will install in the following structure:
  #
  #   install_dir/
  #     cache/<gem-version>.gem #=> a cached copy of the installed gem
  #     gems/<gem-version>/... #=> extracted files
  #     specifications/<gem-version>.gemspec #=> the Gem::Specification
  def install(force = false, install_dir = Gem.dir)
    @install_dir = Pathname.new(install_dir).expand_path
    # If we're forcing the install then disable security unless the security
    # policy says that we only install singed gems.
    @security_policy = nil if force and @security_policy and
                              not @security_policy.only_signed

    begin
      @format = Gem::Format.from_file_by_path @gem, @security_policy
    rescue Gem::Package::FormatError
      raise Gem::InstallError, "invalid gem format for #{@gem}"
    end

    @spec = @format.spec

    unless force then
      if rrv = @spec.required_ruby_version then
        unless rrv.satisfied_by? Gem::Version.new(RUBY_VERSION) then
          raise Gem::InstallError, "#{@spec.name} requires Ruby version #{rrv}"
        end
      end

      if rrgv = @spec.required_rubygems_version then
        unless rrgv.satisfied_by? Gem::Version.new(Gem::RubyGemsVersion) then
          raise Gem::InstallError,
                "#{@spec.name} requires RubyGems version #{rrgv}"
        end
      end

      unless @ignore_dependencies then
        @spec.dependencies.each do |dep_gem|
          ensure_dependency @spec, dep_gem
        end
      end
    end

    raise Gem::FilePermissionError, @install_dir unless
      File.writable? @install_dir

    Gem.ensure_gem_subdirectories @install_dir

    @gem_dir = File.join(@install_dir, "gems", @spec.full_name).untaint
    FileUtils.mkdir_p @gem_dir

    extract_files
    generate_bin
    build_extensions
    write_spec

    cached_gem = File.join install_dir, "cache", @gem.split(/\//).pop
    unless File.exist? cached_gem then
      FileUtils.cp @gem, File.join(@install_dir, "cache")
    end

    say @spec.post_install_message unless @spec.post_install_message.nil?

    @spec.loaded_from = File.join(@install_dir, 'specifications',
                                  "#{@spec.full_name}.gemspec")

    return @spec
  rescue Zlib::GzipFile::Error
    raise Gem::InstallError, "gzip error installing #{@gem}"
  end

  ##
  # Ensure that the dependency is satisfied by the current installation of
  # gem.  If it is not an exception is raised.
  #
  # spec       :: Gem::Specification
  # dependency :: Gem::Dependency
  def ensure_dependency(spec, dependency)
    unless installation_satisfies_dependency? dependency then
      raise Gem::InstallError, "#{spec.name} requires #{dependency}"
    end

    true
  end

  ##
  # True if the current installed gems satisfy the given dependency.
  #
  # dependency :: Gem::Dependency
  def installation_satisfies_dependency?(dependency)
    current_index = Gem::SourceIndex.from_installed_gems
    current_index.find_name(dependency.name, dependency.version_requirements).size > 0
  end

  ##
  # Unpacks the gem into the given directory.
  #
  def unpack(directory)
    @gem_dir = directory
    @format = Gem::Format.from_file_by_path @gem, @security_policy
    extract_files
  end

  ##
  # Writes the .gemspec specification (in Ruby) to the supplied
  # spec_path.
  #
  # spec:: [Gem::Specification] The Gem specification to output
  # spec_path:: [String] The location (path) to write the gemspec to
  #
  def write_spec
    rubycode = @spec.to_ruby

    file_name = File.join @install_dir, 'specifications',
                          "#{@spec.full_name}.gemspec"
    file_name.untaint

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

  def generate_bin
    return if @spec.executables.nil? or @spec.executables.empty?

    # If the user has asked for the gem to be installed in a directory that is
    # the system gem directory, then use the system bin directory, else create
    # (or use) a new bin dir under the install_dir.
    bindir = Gem.bindir @install_dir

    Dir.mkdir bindir unless File.exist? bindir
    raise Gem::FilePermissionError.new(bindir) unless File.writable? bindir

    @spec.executables.each do |filename|
      bin_path = File.join @gem_dir, 'bin', filename
      mode = File.stat(bin_path).mode | 0111
      File.chmod mode, bin_path

      if @wrappers then
        generate_bin_script filename, bindir
      else
        generate_bin_symlink filename, bindir
      end
    end
  end

  ##
  # Creates the scripts to run the applications in the gem.
  #--
  # The Windows script is generated in addition to the regular one due to a
  # bug or misfeature in the Windows shell's pipe.  See
  # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/193379
  #
  def generate_bin_script(filename, bindir)
    File.open(File.join(bindir, File.basename(filename)), "w", 0755) do |file|
      file.print app_script_text(filename)
    end
    generate_windows_script bindir, filename
  end

  ##
  # Creates the symlinks to run the applications in the gem.  Moves
  # the symlink if the gem being installed has a newer version.
  #
  def generate_bin_symlink(filename, bindir)
    if Config::CONFIG["arch"] =~ /dos|win32/i then
      alert_warning "Unable to use symlinks on win32, installing wrapper"
      generate_bin_script filename, bindir
      return
    end

    src = File.join @gem_dir, 'bin', filename
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
    if @env_shebang then
      shebang_env
    else
      shebang_default(spec, install_dir, bin_file_name)
    end
  end

  def shebang_default(spec, install_dir, bin_file_name)
    path = File.join(install_dir, "gems", spec.full_name, spec.bindir, bin_file_name)

    ruby = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

    File.open(path, "rb") do |file|
      first_line = file.readlines("\n").first
      if first_line =~ /^#!/ then
        # Preserve extra words on shebang line, like "-w".  Thanks RPA.
        shebang = first_line.sub(/\A\#!\s*\S*ruby\S*/, "#!#{ruby}")
      else
        # Create a plain shebang line.
        shebang = "#!#{ruby}"
      end

      return shebang.strip  # Avoid nasty ^M issues.
    end
  end

  def shebang_env
    return "#!/usr/bin/env ruby"
  end

  # Return the text for an application file.
  def app_script_text(filename)
    <<-TEXT
#{shebang @spec, @install_dir, filename}
#
# This file was generated by RubyGems.
#
# The application '#{spec.name}' is installed as part of a gem, and
# this file is here to facilitate running it.
#

ENV['GEM_HOME'] ||= '#{@install_dir}'
require 'rubygems'

version = ">= 0"
if ARGV.first =~ /^_(.*)_$/ and Gem::Version.correct? $1 then
  version = $1
  ARGV.shift
end

gem '#{@spec.name}', version
load '#{filename}'
TEXT
  end

  def build_extensions
    return if @spec.extensions.empty?
    say "Building native extensions.  This could take a while..."
    start_dir = Dir.pwd
    dest_path = File.join @gem_dir, @spec.require_paths.first
    ran_rake = false # only run rake once

    @spec.extensions.each do |extension|
      break if ran_rake
      results = []

      builder = case extension
                when /extconf/ then
                  Gem::Ext::ExtConfBuilder
                when /configure/ then
                  Gem::Ext::ConfigureBuilder
                when /rakefile/i, /mkrf_conf/i then
                  ran_rake = true
                  Gem::Ext::RakeBuilder
                else
                  results = ["No builder for extension '#{extension}'"]
                  nil
                end

      begin
        Dir.chdir File.join(@gem_dir, File.dirname(extension))
        results = builder.build(extension, @gem_dir, dest_path, results)
      rescue => ex
        results = results.join "\n"

        File.open('gem_make.out', 'wb') { |f| f.puts results }

        message = <<-EOF
ERROR: Failed to build gem native extension.

#{results}

Gem files will remain installed in #{@gem_dir} for inspection.
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
  def extract_files
    expand_and_validate_gem_dir

    raise ArgumentError, "format required to extract from" if @format.nil?

    @format.file_entries.each do |entry, file_data|
      path = entry['path'].untaint

      if path =~ /\A\// then # for extra sanity
        raise Gem::InstallError,
              "attempt to install file into #{entry['path'].inspect}"
      end

      path = File.expand_path File.join(@gem_dir, path)

      if path !~ /\A#{Regexp.escape @gem_dir}/ then
        msg = "attempt to install file into %p under %p" %
                [entry['path'], @gem_dir]
        raise Gem::InstallError, msg
      end

      FileUtils.mkdir_p File.dirname(path)

      File.open(path, "wb") do |out|
        out.write file_data
      end
    end
  end

  private

  def expand_and_validate_gem_dir
    @gem_dir = Pathname.new(@gem_dir).expand_path

    unless @gem_dir.absolute? then # HACK is this possible after #expand_path?
      raise ArgumentError, "install directory %p not absolute" % @gem_dir
    end

    @gem_dir = @gem_dir.to_str
  end

end

