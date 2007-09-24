require 'test/unit'
require 'test/gemutilities'
require 'rubygems/command'
require 'rubygems/version_option'

class TestGemVersionOption < RubyGemTestCase

  class DummyCommand < Gem::Command
    include Gem::VersionOption

    def initialize
      super 'dummy', 'A dummy command'
    end
  end

  def setup
    super

    @cmd = DummyCommand.new
  end

  def test_add_version_option
    @cmd.add_version_option 'dummy'

    assert @cmd.handles?(%w[--version >1])
  end

  def test_version_option
    @cmd.add_version_option 'dummy'

    @cmd.handle_options %w[--version >1]

    expected = { :version => '>1', :args => [] }

    assert_equal expected, @cmd.options
  end

end

