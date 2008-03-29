#--
# Copyright 2006, 2007 by Chad Fowler, Rich Kilmer, Jim Weirich, Eric Hodel
# and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

# Make sure rubygems isn't already loaded.
if ENV['RUBYOPT'] and defined? Gem then
  ENV.delete 'RUBYOPT'

  ruby = File.join Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name']
  ruby << Config::CONFIG['EXEEXT']

  exec(ruby, 'setup.rb', *ARGV)
end

$:.unshift 'lib'
require 'rubygems'

if ARGV.include? '--help' or ARGV.include? '-h' then
  puts "ruby setup.rb [options]:"
  puts
  puts "RubyGems will install the gem command with a name matching ruby's"
  puts "prefix and suffix.  If ruby was installed as `ruby18`, gem will be"
  puts "installed as `gem18`."
  puts
  puts "By default, this RubyGems will install gem as:"
  puts
  puts "  #{Gem.default_exec_format % 'gem'}"
  puts
  puts "Options:"
  puts
  puts "  --prefix=DIR           Prefix path for installing RubyGems"
  puts "                         Will not affect gem repository location"
  puts
  puts "  --no-format-executable Force installation as `gem`"
  puts
  puts "  --no-rdoc              Don't build RDoc for RubyGems"
  puts
  puts "  --no-ri                Don't build ri for RubyGems"

  exit
end

require 'fileutils'
require 'rbconfig'
require 'rdoc/rdoc'
require 'tmpdir'

include FileUtils::Verbose

# check ruby version

required_version = Gem::Version::Requirement.create("> 1.8.2")

unless required_version.satisfied_by? Gem::Version.new(RUBY_VERSION) then
  abort "Expected Ruby version #{required_version}, was #{RUBY_VERSION}"
end

# install stuff

lib_dir = nil
bin_dir = nil

if ARGV.grep(/^--prefix/).empty? then
  lib_dir = Config::CONFIG['sitelibdir']
  bin_dir = Config::CONFIG['bindir']
else
  prefix = nil

  prefix_arg = ARGV.grep(/^--prefix=/).first
  if prefix_arg =~ /^--prefix=(.*)/ then
    prefix = $1
  else
    path_index = ARGV.index '--prefix'
    prefix = ARGV[path_index + 1]
  end

  prefix = File.expand_path prefix

  raise "invalid --prefix #{prefix.inspect}" if prefix.nil?

  lib_dir = File.join prefix, 'lib'
  bin_dir = File.join prefix, 'bin'

  mkdir_p lib_dir
  mkdir_p bin_dir
end

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
    bin_file_formatted = if ARGV.include? '--no-format-executable' then
                           bin_file
                         else
                           Gem.default_exec_format % bin_file
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

require 'rubygems/source_info_cache'

user_cache_file = Gem::SourceInfoCache.user_cache_file
system_cache_file = Gem::SourceInfoCache.system_cache_file

rm_f user_cache_file if File.writable? File.dirname(user_cache_file)
rm_f system_cache_file if File.writable? File.dirname(system_cache_file)

# install RDoc

gem_doc_dir = File.join Gem.dir, 'doc'

if File.writable? gem_doc_dir then
  puts "Removing old RubyGems RDoc and ri"
  Dir[File.join(Gem.dir, 'doc', 'rubygems-[0-9]*')].each do |dir|
    rm_rf dir
  end

  def run_rdoc(*args)
    args << '--quiet'
    args << '--main' << 'README'
    args << '.' << 'README' << 'LICENSE.txt' << 'GPL.txt'

    r = RDoc::RDoc.new
    r.document args
  end

  rubygems_name = "rubygems-#{Gem::RubyGemsVersion}"

  doc_dir = File.join Gem.dir, 'doc', rubygems_name

  unless ARGV.include? '--no-ri' then
    ri_dir = File.join doc_dir, 'ri'
    puts "Installing #{rubygems_name} ri into #{ri_dir}"
    run_rdoc '--ri', '--op', ri_dir
  end

  unless ARGV.include? '--no-rdoc' then
    rdoc_dir = File.join(doc_dir, 'rdoc')
    puts "Installing #{rubygems_name} rdoc into #{rdoc_dir}"
    run_rdoc '--op', rdoc_dir
  end
else
  puts "Skipping RDoc generation, #{gem_doc_dir} not writable"
  puts "Set the GEM_HOME environment variable if you want RDoc generated"
end

# Remove stubs

def stub?(path)
  return unless File.readable? path
  File.read(path, 40) =~ /^# This file was generated by RubyGems/ and
  File.readlines(path).size < 20
end

puts "As of RubyGems 0.8.0, library stubs are no longer needed."
puts "Searching $LOAD_PATH for stubs to optionally delete (may take a while)"

gemfiles = Dir[File.join("{#{($LOAD_PATH).join(',')}}", '**', '*.rb')]
gemfiles = gemfiles.map { |file| File.expand_path file }.uniq

puts "...done."

seen_stub = false

gemfiles.each do |file|
  next if File.directory? file
  next unless stub? file

  unless seen_stub then
    puts "\nRubyGems has detected stubs that can be removed.  Confirm their removal:"
  end
  seen_stub = true

  print "  * remove #{file}? [y/n] "
  answer = gets

  if answer =~ /y/i then
    unlink file
    puts "        (removed)"
  else
    puts "        (skipping)"
  end
end

if seen_stub then
  puts "Finished with library stubs."
else
  puts "No library stubs found."
end

puts
puts "-" * 78
puts

release_notes = File.join 'doc', 'release_notes',
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

