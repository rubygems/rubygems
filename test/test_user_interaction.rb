require 'test/unit'
require 'stringio'

require 'rubygems'
require 'rubygems/user_interaction'

class TestStreamUI < Test::Unit::TestCase

  def setup
    Gem.send :instance_variable_set, :@configuration, nil
    @cfg = Gem.configuration

    @in = StringIO.new
    @out = StringIO.new
    @err = StringIO.new

    @sui = Gem::StreamUI.new @in, @out, @err
  end

  def test_proress_reporter_silent_nil
    @cfg[:verbose] = nil
    reporter = @sui.progress_reporter 10, 'hi'
    assert_kind_of Gem::StreamUI::SilentProgressReporter, reporter
  end

  def test_proress_reporter_silent_false
    @cfg[:verbose] = false
    reporter = @sui.progress_reporter 10, 'hi'
    assert_kind_of Gem::StreamUI::SilentProgressReporter, reporter
    assert_equal "", @out.string
  end

  def test_proress_reporter_simple
    @cfg[:verbose] = true
    reporter = @sui.progress_reporter 10, 'hi'
    assert_kind_of Gem::StreamUI::SimpleProgressReporter, reporter
    assert_equal "hi\n", @out.string
  end

  def test_proress_reporter_verbose
    @cfg[:verbose] = 0
    reporter = @sui.progress_reporter 10, 'hi'
    assert_kind_of Gem::StreamUI::VerboseProgressReporter, reporter
    assert_equal "hi\n", @out.string
  end
  
end

