require 'test/unit'
require 'test/gemutilities'
require 'rubygems/installer'

class TestGemExtRakeBuilder < RubyGemTestCase

  def setup
    super

    @ext = File.join @tempdir, 'ext'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_class_build
    File.open File.join(@ext, 'Rakefile'), 'w' do |configure|
      configure.puts "task :extension"
    end

    output = []
    realdir = nil # HACK /tmp vs. /private/tmp

    Dir.chdir @ext do
      realdir = Dir.pwd
      Gem::ExtRakeBuilder.build nil, nil, @dest_path, output
    end

    expected = [
      "rake RUBYARCHDIR=#{@dest_path} RUBYLIBDIR=#{@dest_path} extension",
      "(in #{realdir})\n"
    ]

    assert_equal expected, output
  end

  def test_class_build_fail
    File.open File.join(@ext, 'rakefile'), 'w' do |rakefile|
      rakefile.puts "task :extension do abort 'fail' end"
    end

    output = []

    error = assert_raise Gem::InstallError do
      Dir.chdir @ext do
        Gem::ExtRakeBuilder.build nil, nil, @dest_path, output
      end
    end

    expected = <<-EOF.strip
rake failed:

rake RUBYARCHDIR=#{@dest_path} RUBYLIBDIR=#{@dest_path} extension
    EOF

    assert_equal expected, error.message.split("\n")[0..2].join("\n")
  end

end

