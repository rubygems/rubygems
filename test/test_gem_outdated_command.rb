require 'test/unit'
require 'test/gemutilities'
require 'rubygems/gem_commands'

class TestGemOutdatedCommand < RubyGemTestCase

  def setup
    Gem::CommandManager.instance    
    super
  end

  def test_execute
    local_01 = quick_gem 'foo', '0.1'
    local_02 = quick_gem 'foo', '0.2'
    remote_10 = quick_gem 'foo', '1.0'
    remote_20 = quick_gem 'foo', '2.0'

    remote_spec_file = File.join @gemhome, 'specifications',
                                 remote_10.full_name + ".gemspec"
    FileUtils.rm remote_spec_file

    remote_spec_file = File.join @gemhome, 'specifications',
                                 remote_20.full_name + ".gemspec"
    FileUtils.rm remote_spec_file

    oc = Gem::Commands::OutdatedCommand.new

    util_setup_source_info_cache remote_10, remote_20

    ui = MockGemUi.new 
    use_ui ui do oc.execute end

    assert_equal "foo (0.2 < 2.0)\n", ui.output
    assert_equal "", ui.error
  end

end

