#--
# Copyright 2006, 2007 by Chad Fowler, Rich Kilmer, Jim Weirich, Eric Hodel
# and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

# Make sure rubygems isn't already loaded.
if ENV['RUBYOPT'] and defined? Gem then
  ENV.delete 'RUBYOPT'

  require 'rbconfig'
  config = defined?(RbConfig) ? RbConfig : Config

  ruby = File.join config::CONFIG['bindir'], config::CONFIG['ruby_install_name']
  ruby << config::CONFIG['EXEEXT']

  exec(ruby, 'setup.rb', *ARGV)
end

$:.unshift 'lib'
require 'rubygems'
require 'getoptlong'

opts = GetoptLong.new(
    [ '--help',                   '-h', GetoptLong::NO_ARGUMENT ],
    [ '--prefix',                       GetoptLong::REQUIRED_ARGUMENT ],
    [ '--no-format-executable',         GetoptLong::NO_ARGUMENT ],
    [ '--no-rdoc',                      GetoptLong::NO_ARGUMENT ],
    [ '--no-ri',                        GetoptLong::NO_ARGUMENT ],
    [ '--vendor',                       GetoptLong::NO_ARGUMENT ],
    [ '--destdir',                      GetoptLong::REQUIRED_ARGUMENT ]
)

prefix = ''
format_executable = true
rdoc = true
ri = true
site_or_vendor = :sitelibdir
install_destdir = ''

opts.each do | opt, arg |
  case opt
  when '--help'
    puts <<HELP
ruby setup.rb [options]:

RubyGems will install the gem command with a name matching ruby's
prefix and suffix.  If ruby was installed as `ruby18`, gem will be
installed as `gem18`.

By default, this RubyGems will install gem as:
  #{Gem.default_exec_format % 'gem'}

Options:
  --help                 Print this message
  --prefix=DIR           Prefix path for installing RubyGems
                         Will not affect gem repository location
  --no-format-executable Force installation as `gem`
  --no-rdoc              Don't build RDoc for RubyGems
  --no-ri                Don't build ri for RubyGems
  --vendor               Install into vendorlibdir not sitelibdir
                         (Requires Ruby 1.8.7)
  --destdir              Root directory to install rubygems into
                         Used mainly for packaging RubyGems
HELP
    exit 0

  when '--no-rdoc'
    rdoc = false

  when '--no-ri'
    ri = false

  when '--no-format-executable'
    format_executable = false

  when '--prefix'
    prefix = File.expand_path(arg)

  when '--vendor'
    vendor_dir_version = Gem::Version::Requirement.create('>= 1.8.7')
    unless vendor_dir_version.satisfied_by? Gem.ruby_version then
      abort "To use --vendor you need ruby #{vendor_dir_version}, current #{Gem.ruby_version}"
    end
    site_or_vendor = :vendorlibdir

  when '--destdir'
    install_destdir = File.expand_path(arg)
  end
end

require 'fileutils'
require 'rbconfig'
require 'tmpdir'
require 'pathname'

unless install_destdir.empty? then
  default_dir = Pathname.new(Gem.default_dir)
  top_dir = Pathname.new(RbConfig::TOPDIR)
  ENV['GEM_HOME'] ||= File.join(install_destdir,
                                default_dir.relative_path_from(top_dir))
end

include FileUtils::Verbose

# check ruby version

required_version = Gem::Version::Requirement.create("> 1.8.3")

unless required_version.satisfied_by? Gem.ruby_version then
  abort "Expected Ruby version #{required_version}, was #{Gem.ruby_version}"
end

# install stuff

lib_dir = nil
bin_dir = nil

if prefix.empty?
  lib_dir = Gem::ConfigMap[site_or_vendor]
  bin_dir = Gem::ConfigMap[:bindir]
else
  # Apple installed RubyGems into libdir, and RubyGems <= 1.1.0 gets confused
  # about installation location, so switch back to sitelibdir/vendorlibdir.
  if defined?(APPLE_GEM_HOME) and
      # just in case Apple and RubyGems don't get this patched up proper.
     (prefix == Gem::ConfigMap[:libdir] or
      # this one is important
      prefix == File.join(Gem::ConfigMap[:libdir], 'ruby')) then
    lib_dir = Gem::ConfigMap[site_or_vendor]
    bin_dir = Gem::ConfigMap[:bindir]
  else
    lib_dir = File.join prefix, 'lib'
    bin_dir = File.join prefix, 'bin'
  end
end

unless install_destdir.empty?
  top_dir = Pathname.new(RbConfig::TOPDIR)
  lib_dir_p = Pathname.new(lib_dir)
  bin_dir_p = Pathname.new(bin_dir)

  lib_dir = File.join install_destdir, lib_dir_p.relative_path_from(top_dir)
  bin_dir = File.join install_destdir, bin_dir_p.relative_path_from(top_dir)
end

mkdir_p lib_dir
mkdir_p bin_dir

Dir.chdir 'lib' do
  lib_files = Dir[File.join('**', '*rb')]

  lib_files.each do |lib_file|
    dest_file = File.join lib_dir, lib_file
    dest_dir = File.dirname dest_file
    mkdir_p dest_dir unless File.directory? dest_dir

    install lib_file, dest_file, :mode => 0644
  end
end

bin_file_names = []

Dir.chdir 'bin' do
  bin_files = Dir['*']

  bin_files.delete 'update_rubygems'

  bin_files.each do |bin_file|
    bin_file_formatted = if format_executable then
                           Gem.default_exec_format % bin_file
                         else
                           bin_file
                         end

    dest_file = File.join bin_dir, bin_file_formatted
    bin_tmp_file = File.join Dir.tmpdir, bin_file

    begin
      cp bin_file, bin_tmp_file
      bin = File.readlines bin_tmp_file
      bin[0] = "#!#{Gem.ruby}\n"

      File.open bin_tmp_file, 'w' do |fp|
        fp.puts bin.join
      end

      install bin_tmp_file, dest_file, :mode => 0755
      bin_file_names << dest_file
    ensure
      rm bin_tmp_file
    end

    next unless Gem.win_platform?

    begin
      bin_cmd_file = File.join Dir.tmpdir, "#{bin_file}.bat"

      File.open bin_cmd_file, 'w' do |file|
        file.puts <<-TEXT
@ECHO OFF
IF NOT "%~f0" == "~f0" GOTO :WinNT
@"#{File.basename(Gem.ruby)}" "#{dest_file}" %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO :EOF
:WinNT
@"#{File.basename(Gem.ruby)}" "%~dpn0" %*
TEXT
      end

      install bin_cmd_file, "#{dest_file}.bat", :mode => 0755
    ensure
      rm bin_cmd_file
    end
  end
end

# Replace old bin files with ones that abort.

old_bin_files = {
  'gem_mirror' => 'gem mirror',
  'gem_server' => 'gem server',
  'gemlock' => 'gem lock',
  'gemri' => 'ri',
  'gemwhich' => 'gem which',
  'index_gem_repository.rb' => 'gem generate_index',
}

old_bin_files.each do |old_bin_file, new_name|
  old_bin_path = File.join bin_dir, old_bin_file
  next unless File.exist? old_bin_path

  deprecation_message = "`#{old_bin_file}` has been deprecated.  Use `#{new_name}` instead."

  File.open old_bin_path, 'w' do |fp|
    fp.write <<-EOF
#!#{Gem.ruby}

abort "#{deprecation_message}"
    EOF
  end

  next unless Gem.win_platform?

  File.open "#{old_bin_path}.bat", 'w' do |fp|
    fp.puts %{@ECHO.#{deprecation_message}}
  end
end

# Remove source caches
if install_destdir.empty?
  require 'rubygems/source_info_cache'

  user_cache_file = File.join(install_destdir,
                              Gem::SourceInfoCache.user_cache_file)
  system_cache_file = File.join(install_destdir,
                                Gem::SourceInfoCache.system_cache_file)

  rm_f user_cache_file if File.writable? File.dirname(user_cache_file)
  rm_f system_cache_file if File.writable? File.dirname(system_cache_file)
end

# install RDoc

gem_doc_dir = File.join Gem.dir, 'doc'
rubygems_name = "rubygems-#{Gem::RubyGemsVersion}"
rubygems_doc_dir = File.join gem_doc_dir, rubygems_name

if File.writable? gem_doc_dir and
   (not File.exist? rubygems_doc_dir or
    File.writable? rubygems_doc_dir) then
  puts "Removing old RubyGems RDoc and ri"
  Dir[File.join(Gem.dir, 'doc', 'rubygems-[0-9]*')].each do |dir|
    rm_rf dir
  end

  def run_rdoc(*args)
    begin
      gem 'rdoc'
    rescue Gem::LoadError
    end

    require 'rdoc/rdoc'

    args << '--quiet'
    args << '--main' << 'README'
    args << '.' << 'README' << 'LICENSE.txt' << 'GPL.txt'

    r = RDoc::RDoc.new
    r.document args
  end

  if ri then
    ri_dir = File.join rubygems_doc_dir, 'ri'
    puts "Installing #{rubygems_name} ri into #{ri_dir}"
    run_rdoc '--ri', '--op', ri_dir
  end

  if rdoc then
    rdoc_dir = File.join rubygems_doc_dir, 'rdoc'
    puts "Installing #{rubygems_name} rdoc into #{rdoc_dir}"
    run_rdoc '--op', rdoc_dir
  end
else
  puts "Skipping RDoc generation, #{gem_doc_dir} not writable"
  puts "Set the GEM_HOME environment variable if you want RDoc generated"
end

puts
puts "-" * 78
puts

release_notes = File.join File.dirname(__FILE__), 'doc', 'release_notes',
                          "rel_#{Gem::RubyGemsVersion.gsub '.', '_'}.rdoc"

if File.exist? release_notes then
  puts File.read(release_notes)
else
  puts "Oh-no! Unable to find release notes in:\n\t#{release_notes}"
end

puts
puts "-" * 78
puts

puts "RubyGems installed the following executables:"
puts bin_file_names.map { |name| "\t#{name}\n" }
puts

puts "If `gem` was installed by a previous RubyGems installation, you may need"
puts "to remove it by hand."
puts


