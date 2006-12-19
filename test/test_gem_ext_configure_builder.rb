require 'test/unit'
require 'test/gemutilities'

require 'rubygems/installer'

class TestGemExtConfigureBuilder < RubyGemTestCase

  def setup
    super

    @makefile_body =  "all:\n\t@echo ok\ninstall:\n\t@echo ok"

    @ext = File.join @tempdir, 'ext'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_self_build
    File.open File.join(@ext, './configure'), 'w' do |configure|
      configure.puts "#!/bin/sh\necho \"#{@makefile_body}\" > Makefile"
    end

    output = []

    Dir.chdir @ext do
      Gem::ExtConfigureBuilder.build nil, nil, @dest_path, output
    end

    expected = [
      "sh ./configure --prefix=#{@dest_path}",
      "", "make", "ok\n", "make install", "ok\n"
    ]

    assert_equal expected, output
  end

  def test_self_build_fail
    output = []

    error = assert_raise Gem::InstallError do
      Dir.chdir @ext do
        Gem::ExtConfigureBuilder.build nil, nil, @dest_path, output
      end
    end

    expected = "configure failed:

sh ./configure --prefix=#{@dest_path}
./configure: ./configure: No such file or directory
"

    assert_equal expected, error.message

    expected = [
      "sh ./configure --prefix=#{@dest_path}",
      "./configure: ./configure: No such file or directory\n"
    ]

    assert_equal expected, output
  end

  def test_self_build_has_makefile
    File.open File.join(@ext, 'Makefile'), 'w' do |makefile|
      makefile.puts @makefile_body
    end

    output = []
    Dir.chdir @ext do
      Gem::ExtConfigureBuilder.build nil, nil, @dest_path, output
    end

    expected = ['make', "ok\n", "make install", "ok\n"]

    assert_equal expected, output
  end

end

