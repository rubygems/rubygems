require 'rubygems/package/tar_test_case'
require 'rubygems/package'

class TestGemPackageTarReaderEntryMultibyte < Gem::Package::TarTestCase

  def setup
    super

    @contents = "öäü"
    @content_size = 6

    @tar = ''
    @tar << tar_file_header("lib/foo", "", 0, @content_size, Time.now)
    @tar << @contents
    @tar << "\0" * (512 - (@tar.size % 512))

    @entry = util_entry @tar
    io = @entry.instance_variable_get(:@io)
    io.set_encoding "utf-8" if io.respond_to? :set_encoding
  end

  def teardown
    close_util_entry(@entry)
    super
  end

  def close_util_entry(entry)
    entry.instance_variable_get(:@io).close!
  end

  def test_bytes_read_getc
    assert_equal 0, @entry.bytes_read

    c = @entry.getc

    if c.kind_of? Fixnum then
      # Ruby < 1.9 behaviour
      assert_equal 1, @entry.bytes_read
    else
      # Ruby >= 1.9 behaviour
      assert_equal 2, @entry.bytes_read
    end
  end

  def test_bytes_read_read
    assert_equal 0, @entry.bytes_read

    @entry.read

    assert_equal 6, @entry.bytes_read
  end

end
