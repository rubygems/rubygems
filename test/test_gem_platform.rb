require 'test/gemutilities'
require 'test/unit'
require 'rubygems/platform'
require 'rbconfig'

class TestGemPlatform < RubyGemTestCase

  def test_self_local
    util_set_target 'i686', 'darwin8.10.1'

    assert_equal %w[x86 darwin 8], Gem::Platform.local
  end

  def test_self_match
    assert Gem::Platform.match(nil), 'nil == ruby'
    assert Gem::Platform.match(Gem::Platform.local), 'exact match'
    assert Gem::Platform.match(Gem::Platform::RUBY), 'ruby'
  end

  def test_self_match_legacy
    util_set_target 'x86', 'mswin32'

    assert Gem::Platform.match('mswin32'),      'mswin32'
    assert Gem::Platform.match('i386-mswin32'), 'i386-mswin32'

    # oddballs
    assert Gem::Platform.match('i386-mswin32-mq5.3'), 'i386-mswin32-mq5.3'
    assert Gem::Platform.match('i386-mswin32-mq6'),   'i386-mswin32-mq6'
    assert !Gem::Platform.match('win32-1.8.2-VC7'),    'win32-1.8.2-VC7'
    assert !Gem::Platform.match('win32-1.8.4-VC6'),    'win32-1.8.4-VC6'
    assert !Gem::Platform.match('win32-source'),       'win32-source'
    assert !Gem::Platform.match('windows'),            'windows'

    util_set_target 'x86', 'linux'
    assert Gem::Platform.match('i486-linux'), 'i486-linux'
    assert Gem::Platform.match('i586-linux'), 'i586-linux'
    assert Gem::Platform.match('i686-linux'), 'i686-linux'

    util_set_target 'x86', 'darwin8'
    assert Gem::Platform.match('i686-darwin8.4.1'), 'i686-darwin8.4.1'
    assert Gem::Platform.match('i686-darwin8.8.2'), 'i686-darwin8.8.2'

    util_set_target nil, 'java'
    assert Gem::Platform.match('java'), 'java'
    assert Gem::Platform.match('jruby'), 'jruby'

    util_set_target 'powerpc', 'darwin'
    assert Gem::Platform.match('powerpc-darwin'), 'powerpc-darwin'

    util_set_target 'powerpc', 'darwin7'
    assert Gem::Platform.match('powerpc-darwin7.9.0'), 'powerpc-darwin7.9.0'

    util_set_target 'powerpc', 'darwin8'
    assert Gem::Platform.match('powerpc-darwin8.10.0'), 'powerpc-darwin8.10.0'

    util_set_target 'sparc', 'solaris2.8'
    assert Gem::Platform.match('sparc-solaris2.8-mq5.3'), 'sparc-solaris2.8-mq5.3'
  end

  def test_self_match_universal
    util_set_target 'powerpc', 'darwin8'
    assert Gem::Platform.match('universal-darwin8.0'), 'powerpc universal'

    util_set_target 'x86', 'darwin8'
    assert Gem::Platform.match('universal-darwin8.0'), 'x86 universal'

    util_set_target 'universal', 'darwin8'
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
      [nil, 'java']                   => [nil,         'java',    nil],
      [nil, 'java1.4']                => [nil,         'java',    '1.4'],
      %w[powerpc apple-darwin7.9.0]   => ['powerpc',   'darwin',  '7'],
      %w[powerpc apple-darwin8.0]     => ['powerpc',   'darwin',  '8'],
      %w[powerpc apple-darwin9.0]     => ['powerpc',   'darwin',  '9'],
      %w[powerpc unknown-linux-gnu]   => ['powerpc',   'linux',   nil],
      %w[powerpc64 unknown-linux-gnu] => ['powerpc64', 'linux',   nil],
      %w[sparc sun-solaris2.10]       => ['sparc',     'solaris', '2.10'],
      %w[sparc sun-solaris2.8]        => ['sparc',     'solaris', '2.8'],
      %w[sparc sun-solaris2.9]        => ['sparc',     'solaris', '2.9'],
      %w[x86 apple-darwin]            => ['x86',       'darwin',  nil],
      %w[x86 apple-darwin8.4.1]       => ['x86',       'darwin',  '8'],
      %w[x86 mandrake-linux-gnu]      => ['x86',       'linux',   nil],
      %w[x86 mandriva-linux-gnu]      => ['x86',       'linux',   nil],
      %w[x86 mingw32]                 => ['x86',       'mingw32', nil],
      %w[x86 pc-cygwin]               => ['x86',       'cygwin',  nil],
      %w[x86 pc-linux]                => ['x86',       'linux',   nil],
      %w[x86 pc-linux-gnu]            => ['x86',       'linux',   nil],
      %w[x86 pc-mswin32]              => ['x86',       'mswin32', nil],
      %w[x86 pc-solaris2.10]          => ['x86',       'solaris', '2.10'],
      %w[x86 pc-solaris2.8]           => ['x86',       'solaris', '2.8'],
      %w[x86 portbld-freebsd5]        => ['x86',       'freebsd', '5'],
      %w[x86 portbld-freebsd6]        => ['x86',       'freebsd', '6'],
      %w[x86 redhat-linux]            => ['x86',       'linux',   nil],
      %w[x86 redhat-linux-gnu]        => ['x86',       'linux',   nil],
      %w[x86 suse-linux]              => ['x86',       'linux',   nil],
      %w[x86 unknown-freebsd4.11]     => ['x86',       'freebsd', '4'],
      %w[x86 unknown-freebsd6.1]      => ['x86',       'freebsd', '6'],
      %w[x86 unknown-openbsd4.0]      => ['x86',       'openbsd', '4.0'],
      %w[x86_64 pc-linux-gnu]         => ['x86_64',    'linux',   nil],
      %w[x86_64 redhat-linux-gnu]     => ['x86_64',    'linux',   nil],
      %w[x86_64 suse-linux]           => ['x86_64',    'linux',   nil],
      %w[x86_64 unknown-linux-gnu]    => ['x86_64',    'linux',   nil],
      %w[x86_64 unknown-openbsd3.9]   => ['x86_64',    'openbsd', '3.9'],
      %w[x86_64 unknown-openbsd4.0]   => ['x86_64',    'openbsd', '4.0'],
    }

    test_cases.each do |(cpu, os), expected|
      assert_equal expected, Gem::Platform.normalize(cpu, os),
                   [cpu, os].inspect
    end
  end

  def test_self_normalize_test
    assert_equal %w[cpu my_platform 1],
                 Gem::Platform.normalize('cpu', 'my_platform1')

    assert_equal %w[cpu other_platform 1],
                 Gem::Platform.normalize('cpu', 'other_platform1')
  end

end

