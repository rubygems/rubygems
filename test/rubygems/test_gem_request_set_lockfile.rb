require 'rubygems/test_case'
require 'rubygems/request_set'
require 'rubygems/request_set/lockfile'

class TestGemRequestSetLockfile < Gem::TestCase

  def setup
    super

    Gem::RemoteFetcher.fetcher = @fetcher = Gem::FakeFetcher.new

    util_set_arch 'i686-darwin8.10.1'

    @set = Gem::RequestSet.new

    @git_set    = Gem::Resolver::GitSet.new
    @vendor_set = Gem::Resolver::VendorSet.new

    @set.instance_variable_set :@git_set,    @git_set
    @set.instance_variable_set :@vendor_set, @vendor_set

    @gem_deps_file = 'gem.deps.rb'

    @lockfile = Gem::RequestSet::Lockfile.new @set, @gem_deps_file
  end

  def write_gem_deps gem_deps
    open @gem_deps_file, 'w' do |io|
      io.write gem_deps
    end
  end

  def write_lockfile lockfile
    @lock_file = File.expand_path "#{@gem_deps_file}.lock"

    open @lock_file, 'w' do |io|
      io.write lockfile
    end
  end

  def test_add_DEPENDENCIES
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2 do |s|
        s.add_development_dependency 'b'
      end
    end

    @set.gem 'a'
    @set.resolve

    out = []

    @lockfile.add_DEPENDENCIES out

    expected = [
      'DEPENDENCIES',
      '  a',
      nil
    ]

    assert_equal expected, out
  end

  def test_add_DEPENDENCIES_from_gem_deps
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2 do |s|
        s.add_development_dependency 'b'
      end
    end

    dependencies = { 'a' => '~> 2.0' }

    @set.gem 'a'
    @set.resolve
    @lockfile =
      Gem::RequestSet::Lockfile.new @set, @gem_deps_file, dependencies

    out = []

    @lockfile.add_DEPENDENCIES out

    expected = [
      'DEPENDENCIES',
      '  a (~> 2.0)',
      nil
    ]

    assert_equal expected, out
  end

  def test_add_GEM
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2 do |s|
        s.add_dependency 'b'
        s.add_development_dependency 'c'
      end

      fetcher.spec 'b', 2

      fetcher.spec 'bundler', 1
    end

    @set.gem 'a'
    @set.gem 'bundler'
    @set.resolve

    out = []

    @lockfile.add_GEM out, @lockfile.spec_groups

    expected = [
      'GEM',
      '  remote: http://gems.example.com/',
      '  specs:',
      '    a (2)',
      '      b',
      '    b (2)',
      nil
    ]

    assert_equal expected, out
  end

  def test_add_PLATFORMS
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2 do |s|
        s.add_dependency 'b'
      end

      fetcher.spec 'b', 2 do |s|
        s.platform = Gem::Platform::CURRENT
      end
    end

    @set.gem 'a'
    @set.resolve

    out = []

    @lockfile.add_PLATFORMS out

    expected = [
      'PLATFORMS',
      '  ruby',
      '  x86-darwin-8',
      nil
    ]

    assert_equal expected, out
  end

  def test_get
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "\n"
    parser = tokenizer.make_parser nil, nil

    assert_equal :newline, parser.get.first
  end

  def test_get_type_mismatch
    filename = File.expand_path("#{@gem_deps_file}.lock")
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "foo", filename, 1, 0
    parser = tokenizer.make_parser nil, nil

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      parser.get :section
    end

    expected =
      'unexpected token [:text, "foo"], expected :section (at line 1 column 0)'

    assert_equal expected, e.message

    assert_equal 1, e.line
    assert_equal 0, e.column
    assert_equal filename, e.path
  end

  def test_get_type_multiple
    filename = File.expand_path("#{@gem_deps_file}.lock")
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "x", filename, 1
    parser = tokenizer.make_parser nil, nil

    assert parser.get [:text, :section]
  end

  def test_get_type_value_mismatch
    filename = File.expand_path("#{@gem_deps_file}.lock")
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "x", filename, 1
    parser = tokenizer.make_parser nil, nil

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      parser.get :text, 'y'
    end

    expected =
      'unexpected token [:text, "x"], expected [:text, "y"] (at line 1 column 0)'

    assert_equal expected, e.message

    assert_equal 1, e.line
    assert_equal 0, e.column
    assert_equal File.expand_path("#{@gem_deps_file}.lock"), e.path
  end

  def test_peek
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "\n"

    assert_equal :newline, tokenizer.peek.first

    assert_equal :newline, tokenizer.next_token.first

    assert_equal [:EOF], tokenizer.peek
  end

  def test_relative_path_from
    path = @lockfile.relative_path_from '/foo', '/foo/bar'

    assert_equal File.expand_path('/foo'), path

    path = @lockfile.relative_path_from '/foo', '/foo'

    assert_equal '.', path
  end

  def test_skip
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "\n"

    refute_predicate tokenizer, :empty?

    tokenizer.skip :newline

    assert_empty tokenizer
  end

  def test_token_pos
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new ''
    assert_equal [5, 0], tokenizer.token_pos(5)

    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new '', nil, 1, 2
    assert_equal [3, 1], tokenizer.token_pos(5)
  end

  def test_tokenize
    write_lockfile <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b (= 2)
      c (!= 3)
      d (> 4)
      e (< 5)
      f (>= 6)
      g (<= 7)
      h (~> 8)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
    LOCKFILE

    expected = [
      [:section,     'GEM',                0,  0],
      [:newline,     nil,                  3,  0],

      [:entry,       'remote',             2,  1],
      [:text,        @gem_repo,           10,  1],
      [:newline,     nil,                 34,  1],

      [:entry,       'specs',              2,  2],
      [:newline,     nil,                  8,  2],

      [:text,        'a',                  4,  3],
      [:l_paren,     nil,                  6,  3],
      [:text,        '2',                  7,  3],
      [:r_paren,     nil,                  8,  3],
      [:newline,     nil,                  9,  3],

      [:text,        'b',                  6,  4],
      [:l_paren,     nil,                  8,  4],
      [:requirement, '=',                  9,  4],
      [:text,        '2',                 11,  4],
      [:r_paren,     nil,                 12,  4],
      [:newline,     nil,                 13,  4],

      [:text,        'c',                  6,  5],
      [:l_paren,     nil,                  8,  5],
      [:requirement, '!=',                 9,  5],
      [:text,        '3',                 12,  5],
      [:r_paren,     nil,                 13,  5],
      [:newline,     nil,                 14,  5],

      [:text,        'd',                  6,  6],
      [:l_paren,     nil,                  8,  6],
      [:requirement, '>',                  9,  6],
      [:text,        '4',                 11,  6],
      [:r_paren,     nil,                 12,  6],
      [:newline,     nil,                 13,  6],

      [:text,        'e',                  6,  7],
      [:l_paren,     nil,                  8,  7],
      [:requirement, '<',                  9,  7],
      [:text,        '5',                 11,  7],
      [:r_paren,     nil,                 12,  7],
      [:newline,     nil,                 13,  7],

      [:text,        'f',                  6,  8],
      [:l_paren,     nil,                  8,  8],
      [:requirement, '>=',                 9,  8],
      [:text,        '6',                 12,  8],
      [:r_paren,     nil,                 13,  8],
      [:newline,     nil,                 14,  8],

      [:text,        'g',                  6,  9],
      [:l_paren,     nil,                  8,  9],
      [:requirement, '<=',                 9,  9],
      [:text,        '7',                 12,  9],
      [:r_paren,     nil,                 13,  9],
      [:newline,     nil,                 14,  9],

      [:text,        'h',                  6, 10],
      [:l_paren,     nil,                  8, 10],
      [:requirement, '~>',                 9, 10],
      [:text,        '8',                 12, 10],
      [:r_paren,     nil,                 13, 10],
      [:newline,     nil,                 14, 10],

      [:newline,     nil,                  0, 11],

      [:section,     'PLATFORMS',          0, 12],
      [:newline,     nil,                  9, 12],

      [:text,        Gem::Platform::RUBY,  2, 13],
      [:newline,     nil,                  6, 13],

      [:newline,     nil,                  0, 14],

      [:section,     'DEPENDENCIES',       0, 15],
      [:newline,     nil,                 12, 15],

      [:text,        'a',                  2, 16],
      [:newline,     nil,                  3, 16],
    ]

    assert_equal expected, @lockfile.tokenize.to_a
  end

  def test_tokenize_capitals
    write_lockfile <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    Ab (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  Ab
    LOCKFILE

    expected = [
      [:section, 'GEM',                0, 0],
      [:newline, nil,                  3, 0],
      [:entry,   'remote',             2, 1],
      [:text,    @gem_repo,           10, 1],
      [:newline, nil,                 34, 1],
      [:entry,   'specs',              2, 2],
      [:newline, nil,                  8, 2],
      [:text,    'Ab',                 4, 3],
      [:l_paren, nil,                  7, 3],
      [:text,    '2',                  8, 3],
      [:r_paren, nil,                  9, 3],
      [:newline, nil,                 10, 3],
      [:newline, nil,                  0, 4],
      [:section, 'PLATFORMS',          0, 5],
      [:newline, nil,                  9, 5],
      [:text,    Gem::Platform::RUBY,  2, 6],
      [:newline, nil,                  6, 6],
      [:newline, nil,                  0, 7],
      [:section, 'DEPENDENCIES',       0, 8],
      [:newline, nil,                 12, 8],
      [:text,    'Ab',                 2, 9],
      [:newline, nil,                  4, 9],
    ]

    assert_equal expected, @lockfile.tokenize.to_a
  end

  def test_tokenize_conflict_markers
    write_lockfile '<<<<<<<'

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      @lockfile.tokenize
    end

    assert_equal "your #{@lock_file} contains merge conflict markers (at line 0 column 0)",
                 e.message

    write_lockfile '|||||||'

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      @lockfile.tokenize
    end

    assert_equal "your #{@lock_file} contains merge conflict markers (at line 0 column 0)",
                 e.message

    write_lockfile '======='

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      @lockfile.tokenize
    end

    assert_equal "your #{@lock_file} contains merge conflict markers (at line 0 column 0)",
                 e.message

    write_lockfile '>>>>>>>'

    e = assert_raises Gem::RequestSet::Lockfile::ParseError do
      @lockfile.tokenize
    end

    assert_equal "your #{@lock_file} contains merge conflict markers (at line 0 column 0)",
                 e.message
  end

  def test_tokenize_git
    write_lockfile <<-LOCKFILE
DEPENDENCIES
  a!
    LOCKFILE

    expected = [
      [:section, 'DEPENDENCIES',  0,  0],
      [:newline, nil,            12,  0],

      [:text,    'a',             2,  1],
      [:bang,    nil,             3,  1],
      [:newline, nil,             4,  1],
    ]

    assert_equal expected, @lockfile.tokenize.to_a
  end

  def test_tokenize_multiple
    write_lockfile <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b (~> 3.0, >= 3.0.1)
    LOCKFILE

    expected = [
      [:section,     'GEM',      0,  0],
      [:newline,     nil,        3,  0],

      [:entry,       'remote',   2,  1],
      [:text,        @gem_repo, 10,  1],
      [:newline,     nil,       34,  1],

      [:entry,       'specs',    2,  2],
      [:newline,     nil,        8,  2],

      [:text,        'a',        4,  3],
      [:l_paren,     nil,        6,  3],
      [:text,        '2',        7,  3],
      [:r_paren,     nil,        8,  3],
      [:newline,     nil,        9,  3],

      [:text,        'b',        6,  4],
      [:l_paren,     nil,        8,  4],
      [:requirement, '~>',       9,  4],
      [:text,        '3.0',     12,  4],
      [:comma,       nil,       15,  4],
      [:requirement, '>=',      17,  4],
      [:text,        '3.0.1',   20,  4],
      [:r_paren,     nil,       25,  4],
      [:newline,     nil,       26,  4],
    ]

    assert_equal expected, @lockfile.tokenize.to_a
  end

  def test_to_s_gem
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_dependency
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2, 'c' => '>= 0', 'b' => '>= 0'
      fetcher.spec 'b', 2
      fetcher.spec 'c', 2
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b
      c
    b (2)
    c (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
  b
  c
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_dependency_non_default
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2, 'b' => '>= 1'
      fetcher.spec 'b', 2
    end

    @set.gem 'b'
    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b (>= 1)
    b (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
  b
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_dependency_requirement
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2, 'b' => '>= 0'
      fetcher.spec 'b', 2
    end

    @set.gem 'a', '>= 1'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)
      b
    b (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a (>= 1)
  b
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_path
    name, version, directory = vendor_gem

    @vendor_set.add_vendor_gem name, directory

    @set.gem 'a'

    expected = <<-LOCKFILE
PATH
  remote: #{directory}
  specs:
    #{name} (#{version})

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a!
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_path_absolute
    name, version, directory = vendor_gem

    @vendor_set.add_vendor_gem name, File.expand_path(directory)

    @set.gem 'a'

    expected = <<-LOCKFILE
PATH
  remote: #{directory}
  specs:
    #{name} (#{version})

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a!
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_platform
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2 do |spec|
        spec.platform = Gem::Platform.local
      end
    end

    @set.gem 'a'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2-#{Gem::Platform.local})

PLATFORMS
  #{Gem::Platform.local}

DEPENDENCIES
  a
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_gem_source
    spec_fetcher do |fetcher|
      fetcher.spec 'a', 2
      fetcher.clear
    end

    spec_fetcher 'http://other.example/' do |fetcher|
      fetcher.spec 'b', 2
      fetcher.clear
    end

    Gem.sources << 'http://other.example/'

    @set.gem 'a'
    @set.gem 'b'

    expected = <<-LOCKFILE
GEM
  remote: #{@gem_repo}
  specs:
    a (2)

GEM
  remote: http://other.example/
  specs:
    b (2)

PLATFORMS
  #{Gem::Platform::RUBY}

DEPENDENCIES
  a
  b
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_to_s_git
    _, _, repository, = git_gem

    head = nil

    Dir.chdir repository do
      FileUtils.mkdir 'b'

      Dir.chdir 'b' do
        b = Gem::Specification.new 'b', 1 do |s|
          s.add_dependency 'a', '~> 1.0'
          s.add_dependency 'c', '~> 1.0'
        end

        open 'b.gemspec', 'w' do |io|
          io.write b.to_ruby
        end

        system @git, 'add', 'b.gemspec'
        system @git, 'commit', '--quiet', '-m', 'add b/b.gemspec'
      end

      FileUtils.mkdir 'c'

      Dir.chdir 'c' do
        c = Gem::Specification.new 'c', 1

        open 'c.gemspec', 'w' do |io|
          io.write c.to_ruby
        end

        system @git, 'add', 'c.gemspec'
        system @git, 'commit', '--quiet', '-m', 'add c/c.gemspec'
      end

      head = `#{@git} rev-parse HEAD`.strip
    end

    @git_set.add_git_gem 'a', repository, 'HEAD', true
    @git_set.add_git_gem 'b', repository, 'HEAD', true
    @git_set.add_git_gem 'c', repository, 'HEAD', true

    @set.gem 'b'

    expected = <<-LOCKFILE
GIT
  remote: #{repository}
  revision: #{head}
  specs:
    a (1)
    b (1)
      a (~> 1.0)
      c (~> 1.0)
    c (1)

PLATFORMS
  ruby

DEPENDENCIES
  a!
  b!
  c!
    LOCKFILE

    assert_equal expected, @lockfile.to_s
  end

  def test_unget
    tokenizer = Gem::RequestSet::Lockfile::Tokenizer.new "\n"
    tokenizer.unshift :token
    parser = tokenizer.make_parser nil, nil

    assert_equal :token, parser.get
  end

  def test_write
    @lockfile.write

    gem_deps_lock_file = "#{@gem_deps_file}.lock"

    assert_path_exists gem_deps_lock_file

    refute_empty File.read gem_deps_lock_file
  end

  def test_write_error
    @set.gem 'nonexistent'

    gem_deps_lock_file = "#{@gem_deps_file}.lock"

    open gem_deps_lock_file, 'w' do |io|
      io.write 'hello'
    end

    assert_raises Gem::UnsatisfiableDependencyError do
      @lockfile.write
    end

    assert_path_exists gem_deps_lock_file

    assert_equal 'hello', File.read(gem_deps_lock_file)
  end

end

