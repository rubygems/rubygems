require 'rubygems/test_case'
require 'rubygems/builder'
require 'rubygems/package'

require 'rubygems/deprecate'

class TestDeprecate < Gem::TestCase

  def setup
    Deprecate.saved_warnings.clear
    @original_skip = Deprecate.skip
    Deprecate.skip = false
  end
  
  def teardown
    Deprecate.saved_warnings.clear
    Deprecate.skip = @original_skip
  end

  def test_defaults
    assert_equal Deprecate::SKIP_DEFAULT, @original_skip
  end

  def test_assignment
    Deprecate.skip = false
    assert_equal false, Deprecate.skip

    Deprecate.skip = true
    assert_equal true, Deprecate.skip

    Deprecate.skip = nil
    assert([true,false].include? Deprecate.skip)
  end

  def test_skip
    Deprecate.skip_during do
      assert_equal true, Deprecate.skip
    end

    Deprecate.skip_during(false) do
      assert_equal false, Deprecate.skip
    end

    Deprecate.skip_during(nil) do
      assert_equal Deprecate::SKIP_DEFAULT, Deprecate.skip
    end

    Deprecate.skip = nil
  end

  ### stolen from Wrong::Helpers

  # Usage:
  # capturing { puts "hi" } => "hi\n"
  # capturing(:stderr) { $stderr.puts "hi" } => "hi\n"
  # out, err = capturing(:stdout, :stderr) { ... }
  #
  # see http://www.justskins.com/forums/closing-stderr-105096.html for more explanation
  def capturing(*streams)
    streams = [:stdout] if streams.empty?
    original = {}
    captured = {}

    # reassign the $ variable (which is used by well-behaved code e.g. puts)
    streams.each do |stream|
      original[stream] = (stream == :stdout ? $stdout : $stderr)
      captured[stream] = StringIO.new
      reassign_stream(stream, captured)
    end

    yield

    # return either one string, or an array of two strings
    if streams.size == 1
      captured[streams.first].string
    else
      [captured[streams[0]].string.to_s, captured[streams[1]].string.to_s]
    end

  ensure

    streams.each do |stream|
      # bail if stream was reassigned inside the block
      if (stream == :stdout ? $stdout : $stderr) != captured[stream]
        raise "#{stream} was reassigned while being captured"
      end
      # support nested calls to capturing
      original[stream] << captured[stream].string if original[stream].is_a? StringIO
      reassign_stream(stream, original)
    end
  end

  private
  def reassign_stream(which, streams)
    case which
    when :stdout
      $stdout = streams[which]
    when :stderr
      $stderr = streams[which]
    end
  end
  ### end of Wrong::Helpers code

  public
  def test_has_a_place_to_save_warnings
    assert_empty Deprecate.saved_warnings    
  end

  class Thing
    extend Deprecate
    attr_accessor :message
    def foo
      @message = "foo"
    end
    def bar
      @message = "bar"
    end
    def goo
      @message = "goo"
    end
    deprecate :foo, :bar, 2099, 3
    deprecate :goo, :bar, 2099, 4
  end

  def test_deprecated_method_calls_the_old_method
    capturing :stderr do
      thing = Thing.new
      thing.foo
      assert_equal "foo", thing.message
    end
  end

  def test_deprecated_method_outputs_a_warning
    out, err = capturing(:stdout, :stderr) do
      thing = Thing.new
      thing.foo
    end
    assert_equal "", out
    assert err =~ /Thing#foo is deprecated; use bar instead/, err
    assert err =~ /on or after 2099-03-01/, err
  end

  def test_saves_warnings
    capturing :stderr do
      thing = Thing.new
      thing.foo
      thing.goo
      assert_equal 2, Deprecate.saved_warnings.size
    end
  end

  def test_suppresses_duplicate_warnings
    capturing :stderr do
      line1 = line2 = nil
      thing = Thing.new
      3.times do
        thing.foo; line1 = __LINE__
      end
      thing.foo; line2 = __LINE__
      assert_equal 2, Deprecate.saved_warnings.size
      assert_equal line1, Deprecate.saved_warnings[0].location.last
      assert_equal line2, Deprecate.saved_warnings[1].location.last
    end
  end

  def test_suppresses_further_warnings_until_exit
    Deprecate.saved_warnings.clear
  end

  def test_report
    err = capturing :stderr do      
      thing = Thing.new
      thing.foo
      thing.foo
      thing.goo
      thing.foo
      s = Deprecate.report
      assert_equal s, <<-REPORT
Some of your installed gems called deprecated methods. See http://blog.zenspider.com/2011/05/rubygems-18-is-coming.html for background. Use 'gem pristine --all' to fix or 'rubygems update --system 1.7.2' to downgrade.
TestDeprecate::Thing#foo is deprecated; use bar instead. It will be removed on or after 2099-03-01.
  called from /Users/chaffee/dev/rubygems/test/rubygems/test_deprecate.rb:173
  called from /Users/chaffee/dev/rubygems/test/rubygems/test_deprecate.rb:174
  called from /Users/chaffee/dev/rubygems/test/rubygems/test_deprecate.rb:176
TestDeprecate::Thing#goo is deprecated; use bar instead. It will be removed on or after 2099-04-01.
  called from /Users/chaffee/dev/rubygems/test/rubygems/test_deprecate.rb:175
      REPORT
    end
  end
end
