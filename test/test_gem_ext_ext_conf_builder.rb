require 'test/unit'
require 'test/gemutilities'
require 'rubygems/installer'

class TestGemExtExtConfBuilder < RubyGemTestCase

  def setup
    super

    @ext = File.join @tempdir, 'ext'
    @dest_path = File.join @tempdir, 'prefix'

    FileUtils.mkdir_p @ext
    FileUtils.mkdir_p @dest_path
  end

  def test_class_build
    File.open File.join(@ext, 'extconf.rb'), 'w' do |extconf|
      extconf.puts "require 'mkmf'\ncreate_makefile 'foo'"
    end

    output = []

    Dir.chdir @ext do
      Gem::ExtExtConfBuilder.build 'extconf.rb', nil, @dest_path, output
    end

    expected = [
      "ruby extconf.rb",
      "creating Makefile\n",
      "make",
      "make: Nothing to be done for `all'.\n",
      "make install",
      "make: Nothing to be done for `install'.\n"
    ]

    assert_equal expected, output
  end

  def test_class_build_extconf_bad
    File.open File.join(@ext, 'extconf.rb'), 'w' do |extconf|
      extconf.puts "require 'mkmf'"
      extconf.puts "have_library 'nonexistent'"
      extconf.puts "create_makefile 'foo'"
    end

    File.open File.join(@ext, 'foo.c'), 'w' do |foo|
      foo.puts "void Init_foo() { nonexistent(); }"
    end

    output = []

    Dir.chdir @ext do
      Gem::ExtExtConfBuilder.build 'extconf.rb', nil, @dest_path, output
    end

    expected = [
      "ruby extconf.rb",
      "checking for main() in -lnonexistent... no
creating Makefile\n",
      "make"
    ]

    assert_equal expected, output[0, 3]
  end

  def test_class_build_extconf_fail
    File.open File.join(@ext, 'extconf.rb'), 'w' do |extconf|
      extconf.puts "require 'mkmf'"
      extconf.puts "have_library 'nonexistent' or abort 'need libnonexistent'"
      extconf.puts "create_makefile 'foo'"
    end

    output = []

    error = assert_raise Gem::InstallError do
      Dir.chdir @ext do
        Gem::ExtExtConfBuilder.build 'extconf.rb', nil, @dest_path, output
      end
    end

    extconf_output = <<-EOF
checking for main() in -lnonexistent... no
need libnonexistent
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of
necessary libraries and/or headers.  Check the mkmf.log file for more
details.  You may need configuration options.

Provided configuration options:
\t--with-opt-dir
\t--without-opt-dir
\t--with-opt-include
\t--without-opt-include=${opt-dir}/include
\t--with-opt-lib
\t--without-opt-lib=${opt-dir}/lib
\t--with-make-prog
\t--without-make-prog
\t--srcdir=.
\t--curdir
\t--ruby=/usr/local/bin/ruby
\t--with-nonexistentlib
\t--without-nonexistentlib
    EOF

    expected = <<-EOF
extconf failed:

ruby extconf.rb
#{extconf_output.strip}
    EOF

    assert_equal expected, error.message

    expected = ["ruby extconf.rb", extconf_output]

    assert_equal expected, output
  end

  def test_class_make
    output = []
    makefile_path = File.join(@ext, 'Makefile')
    File.open makefile_path, 'w' do |makefile|
      makefile.puts "RUBYARCHDIR = $(foo)$(target_prefix)"
      makefile.puts "RUBYLIBDIR = $(bar)$(target_prefix)"
      makefile.puts "all:"
      makefile.puts "install:"
    end

    Dir.chdir @ext do
      Gem::ExtExtConfBuilder.make @ext, output
    end

    expected = [
      "make",
      "make: Nothing to be done for `all'.\n",
      "make install",
      "make: Nothing to be done for `install'.\n",
    ]

    assert_equal expected, output

    edited_makefile = <<-EOF
RUBYARCHDIR = #{@ext}$(target_prefix)
RUBYLIBDIR = #{@ext}$(target_prefix)
all:
install:
    EOF

    assert_equal edited_makefile, File.read(makefile_path)
  end

  def test_class_make_no_Makefile
    error = assert_raise Gem::InstallError do
      Dir.chdir @ext do
        Gem::ExtExtConfBuilder.make @ext, ['output']
      end
    end

    expected = <<-EOF.strip
Makefile not found:

output
    EOF

    assert_equal expected, error.message
  end

end

