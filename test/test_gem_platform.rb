require 'test/gemutilities'
require 'test/unit'
require 'rubygems/platform'
require 'rbconfig'

class TestGemPlatform < RubyGemTestCase

  def test_self_local
    util_set_arch 'i686-darwin8.10.1'

    assert_equal %w[x86 darwin 8], Gem::Platform.local
  end

  def test_self_match
    assert Gem::Platform.match(nil), 'nil == ruby'
    assert Gem::Platform.match(Gem::Platform.local), 'exact match'
    assert Gem::Platform.match(Gem::Platform::RUBY), 'ruby'
  end

  def test_self_match_legacy
    util_set_arch 'i386-mswin32'

    assert Gem::Platform.match('mswin32'),      'mswin32'
    assert Gem::Platform.match('i386-mswin32'), 'i386-mswin32'

    # oddballs
    assert Gem::Platform.match('i386-mswin32-mq5.3'), 'i386-mswin32-mq5.3'
    assert Gem::Platform.match('i386-mswin32-mq6'),   'i386-mswin32-mq6'
    assert !Gem::Platform.match('win32-1.8.2-VC7'),    'win32-1.8.2-VC7'
    assert !Gem::Platform.match('win32-1.8.4-VC6'),    'win32-1.8.4-VC6'
    assert !Gem::Platform.match('win32-source'),       'win32-source'
    assert !Gem::Platform.match('windows'),            'windows'

    util_set_arch 'i686-linux'
    assert Gem::Platform.match('i486-linux'), 'i486-linux'
    assert Gem::Platform.match('i586-linux'), 'i586-linux'
    assert Gem::Platform.match('i686-linux'), 'i686-linux'

    util_set_arch 'i686-darwin8'
    assert Gem::Platform.match('i686-darwin8.4.1'), 'i686-darwin8.4.1'
    assert Gem::Platform.match('i686-darwin8.8.2'), 'i686-darwin8.8.2'

    util_set_arch 'java'
    assert Gem::Platform.match('java'), 'java'
    assert Gem::Platform.match('jruby'), 'jruby'

    util_set_arch 'powerpc-darwin'
    assert Gem::Platform.match('powerpc-darwin'), 'powerpc-darwin'

    util_set_arch 'powerpc-darwin7'
    assert Gem::Platform.match('powerpc-darwin7.9.0'), 'powerpc-darwin7.9.0'

    util_set_arch 'powerpc-darwin8'
    assert Gem::Platform.match('powerpc-darwin8.10.0'), 'powerpc-darwin8.10.0'

    util_set_arch 'sparc-solaris2.8'
    assert Gem::Platform.match('sparc-solaris2.8-mq5.3'), 'sparc-solaris2.8-mq5.3'
  end

  def test_self_match_universal
    util_set_arch 'powerpc-darwin8'
    assert Gem::Platform.match('universal-darwin8.0'), 'powerpc universal'

    util_set_arch 'i686-darwin8'
    assert Gem::Platform.match('universal-darwin8.0'), 'x86 universal'

    util_set_arch 'universal-darwin8'
    assert Gem::Platform.match('powerpc-darwin8.0'), 'universal ppc'
    assert Gem::Platform.match('universal-darwin8.0'), 'universal universal'
    assert Gem::Platform.match('i686-darwin8.0'), 'universal x86'
  end

  def test_self_match_version
    assert Gem::Platform.match(['x86', 'darwin', nil]), 'versionless == any'
    assert !Gem::Platform.match(['x86', 'darwin', '7']), 'mismatch'
    assert Gem::Platform.match(['x86', 'darwin', '8']), 'match'
    assert !Gem::Platform.match(['x86', 'darwin', '9']), 'mismatch'
  end

  def test_self_normalize
    test_cases = {
      'amd64-freebsd6'         => ['amd64',     'freebsd',   '6'],
      'hppa2.0w-hpux11.31'     => ['hppa2.0w',  'hpux',      '11'],
      'java'                   => [nil,         'java',      nil],
      'powerpc-aix5.3.0.0'     => ['powerpc',   'aix',       '5'],
      'powerpc-darwin7'        => ['powerpc',   'darwin',    '7'],
      'powerpc-darwin8'        => ['powerpc',   'darwin',    '8'],
      'powerpc-linux'          => ['powerpc',   'linux',     nil],
      'powerpc64-linux'        => ['powerpc64', 'linux',     nil],
      'sparc-solaris2.10'      => ['sparc',     'solaris',   '2.10'],
      'sparc-solaris2.8'       => ['sparc',     'solaris',   '2.8'],
      'sparc-solaris2.9'       => ['sparc',     'solaris',   '2.9'],
      'universal-darwin8'      => ['universal', 'darwin',    '8'],
      'universal-darwin9'      => ['universal', 'darwin',    '9'],
      'i386-cygwin'            => ['x86',       'cygwin',    nil],
      'i686-darwin'            => ['x86',       'darwin',    nil],
      'i686-darwin8.4.1'       => ['x86',       'darwin',    '8'],
      'i386-freebsd4.11'       => ['x86',       'freebsd',   '4'],
      'i386-freebsd5'          => ['x86',       'freebsd',   '5'],
      'i386-freebsd6'          => ['x86',       'freebsd',   '6'],
      'i386-freebsd7'          => ['x86',       'freebsd',   '7'],
      'i386-java1.5'           => ['x86',       'java',      '1.5'],
      'x86-java1.6'            => ['x86',       'java',      '1.6'],
      'i386-java1.6'           => ['x86',       'java',      '1.6'],
      'i686-linux'             => ['x86',       'linux',     nil],
      'i586-linux'             => ['x86',       'linux',     nil],
      'i486-linux'             => ['x86',       'linux',     nil],
      'i386-linux'             => ['x86',       'linux',     nil],
      'i586-linux-gnu'         => ['x86',       'linux',     nil],
      'i386-linux-gnu'         => ['x86',       'linux',     nil],
      'i386-mingw32'           => ['x86',       'mingw32',   nil],
      'i386-mswin32'           => ['x86',       'mswin32',   nil],
      'i386-netbsdelf'         => ['x86',       'netbsdelf', nil],
      'i386-openbsd4.0'        => ['x86',       'openbsd',   '4.0'],
      'i386-solaris2.10'       => ['x86',       'solaris',   '2.10'],
      'i386-solaris2.8'        => ['x86',       'solaris',   '2.8'],
      'x86_64-linux'           => ['x86_64',    'linux',     nil],
      'x86_64-openbsd3.9'      => ['x86_64',    'openbsd',   '3.9'],
      'x86_64-openbsd4.0'      => ['x86_64',    'openbsd',   '4.0'],
    }

    test_cases.each do |arch, expected|
      assert_equal expected, Gem::Platform.normalize(arch), arch.inspect
    end
  end

  def test_self_normalize_test
    assert_equal %w[cpu my_platform 1],
                 Gem::Platform.normalize('cpu-my_platform1')

    assert_equal %w[cpu other_platform 1],
                 Gem::Platform.normalize('cpu-other_platform1')
  end

end

