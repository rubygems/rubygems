require 'test/unit'
require 'fileutils'
require 'test/insure_session'
require 'test/brokenbuildgem'

# ====================================================================
class TestExtensionGems < Test::Unit::TestCase
  def setup
    @orig_gem_home = ENV['GEM_HOME']
    ENV['GEM_HOME'] = File.expand_path("test/data/gemhome")
    @gem_path = File.expand_path("bin/gem")
    lib_path = File.expand_path("lib")
    @ruby_options = "-I#{lib_path} -I."
    @verbose = false
    Dir.chdir("pkgs/sources") do
      load "sources.gemspec"
      spec = Gem.sources_spec
      gem_file = Gem::Builder.new(spec).build
      Gem::Installer.new(gem_file).install(true, ENV['GEM_HOME'], false)
    end
  end

  def teardown
    FileUtils.rm_rf 'test/data/broken_build/broken-build-0.0.1.gem'
    ENV['GEM_HOME'] = @orig_gem_home
    Gem.clear_paths
  end
  
  def test_gem_with_broken_extension_does_not_install
    BrokenBuildGem.install(self)
    assert_no_match(/Successfully installed/, @out)
  end
  
  # Run a gem command for the functional test.
  def gem(options="")
    shell = Session::Shell.new
    options = options + " --config-file missing_file" if options !~ /--config-file/
    command = "#{Gem.ruby} #{@ruby_options} #{@gem_path} #{options}"
    puts "\n\nCOMMAND: [#{command}]" if @verbose
    @out, @err = shell.execute command
    @status = shell.exit_status
    puts "STATUS:  [#{@status}]" if @verbose
    puts "OUTPUT:  [#{@out}]" if @verbose
    puts "ERROR:   [#{@err}]" if @verbose
    puts "PWD:     [#{Dir.pwd}]" if @verbose
    shell.close
  end  
end
