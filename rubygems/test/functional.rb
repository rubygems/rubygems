require 'test/unit'
require 'rubygems'

begin
  require_gem 'session'
rescue LoadError => e
  print "Required Gem 'Session' missing.  Install now from RubyGems distribution? [Yn]"
  answer = gets
  if(answer =~ /^y/i || answer =~ /^[^a-zA-Z0-9]$/) then
    path_to_gem = File.join(File.dirname(File.expand_path(__FILE__)), "..", "redist", "session.gem")
    Gem::Installer.new(path_to_gem).install
    require_gem 'session'
  else
    puts "Test cancelled...quitting"
    exit(1)
  end
end


class FunctionalTest < Test::Unit::TestCase
  def setup
    @shell = Session::Shell.new
    Dir.chdir(File.join(
      File.dirname(File.expand_path(__FILE__)),
      "..")
      )
  end

  def test_gem_help
    out,err = @shell.execute "ruby -I lib bin/gem --help"
    assert_match(/Usage:/, out)
  end

  def test_gem_no_args_shows_help
    out,err = @shell.execute "ruby -I lib bin/gem"
    assert_match(/Usage:/, out)
  end

  def test_bogus_source_hoses_up_remote_search_but_gem_command_gives_decent_error_message
    out,err = @shell.execute "ruby -I lib -rtest/bogussources bin/gem --remote --search=asdf"
    assert_match(/^Error fetching remote gem cache/, err)
  end

  def test_bogus_source_hoses_up_remote_install_but_gem_command_gives_decent_error_message
    out,err = @shell.execute "ruby -I lib -rtest/bogussources bin/gem --remote --install=asdf"
    assert_match(/^Error fetching remote gem cache/, err)
  end


end
