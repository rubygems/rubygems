require 'rbconfig'
require 'find'
require 'ftools'

include Config

$srcdir = CONFIG["srcdir"]
$version = CONFIG["MAJOR"]+"."+CONFIG["MINOR"]
$libdir = File.join(CONFIG["libdir"], "ruby", $version)
$archdir = File.join($libdir, CONFIG["arch"])
$site_libdir = $:.find {|x| x =~ /site_ruby$/}
if !$site_libdir
  $site_libdir = File.join($libdir, "site_ruby")
elsif $site_libdir !~ Regexp.new(Regexp.quote($version))
  $site_libdir = File.join($site_libdir, $version)
end

def install_rb(srcdir = nil)
  ### Install 'lib' files.

  libdir = "lib"
  libdir = File.join(srcdir, libdir) if srcdir
  paths = []
  dirs = []
  Find.find(libdir) do |f|
    next unless FileTest.file?(f)
    next if (f = f[libdir.length+1..-1]) == nil
    next if (/CVS$/ =~ File.dirname(f))
    paths.push f
    dirs |= [File.dirname(f)]
  end

  # Create the necessary directories.
  for f in dirs
    next if f == "."
    next if f == "CVS"
    File::makedirs(File.join($site_libdir, f))
  end

  # Install the files.
  for f in paths
    File::install(File.join("lib", f), File.join($site_libdir, f), 0644, true)
  end
  gem_dir = File.join(Config::CONFIG['libdir'], 'ruby', 'gems', Config::CONFIG['ruby_version'])
  ["specifications", "cache"].each do |subdir|
    File::makedirs(File.join(gem_dir, subdir))
  end

  ## Install the 'bin' files.

  bindir = CONFIG['bindir']
  is_windows_platform = CONFIG["arch"] =~ /dos|win32/i
  Find.find('bin') do |f|
    next if f =~ /\bCVS\b/
    next if FileTest.directory?(f)
    next if f =~ /\.rb$/
    source = f
    target = File.join(bindir, File.basename(f))
    File::install(source, target, 0755, true)
    if is_windows_platform
      File.open(target+".cmd", "w") do |file|
        file.puts "@ruby #{target} %1 %2 %3 %4 %5 %6 %7 %8 %9"
      end
    end
  end

  ## Install the 'sources' package bundled with RubyGems.

  Dir.chdir("packages/sources")
    load("sources.gemspec")
    spec = Gem.sources_spec
    Gem::Builder.new(spec).build
    Gem::Installer.new(spec.name + "-" + spec.version.to_s + ".gem").install(true, Gem.dir)
  Dir.chdir("../..")
end

install_rb
