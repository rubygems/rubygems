require "rubygems/test_case"
require "rubygems/patcher"

class TestGemPatch < Gem::TestCase
  def setup
    super

    @gems_dir  = File.join @tempdir, 'gems'
    @lib_dir = File.join @tempdir, 'gems', 'lib'
    FileUtils.mkdir_p @lib_dir
  end

  ##
  # Test changing a file in a gem with -p1 option

  def test_change_file_patch
    gemfile = bake_testing_gem

    patches = []
    patches << bake_change_file_patch

    # Creates new patched gem in @gems_dir
    patcher = Gem::Patcher.new(gemfile, @gems_dir)
    patched_gem = patcher.patch_with(patches, 1)

    # Unpack
    package = Gem::Package.new patched_gem
    package.extract_files @gems_dir

    assert_equal patched_file, file_contents('foo.rb')
  end

  ##
  # Test adding a file into a gem with -p0 option

  def test_new_file_patch
    gemfile = bake_testing_gem

    patches = []
    patches << bake_new_file_patch

    # Create a new patched gem in @gems_fir
    patcher = Gem::Patcher.new(gemfile, @gems_dir)
    patched_gem = patcher.patch_with(patches, 0)

    # Unpack
    package = Gem::Package.new patched_gem
    package.extract_files @gems_dir

    assert_equal original_file, file_contents('bar.rb')
  end

  ##
  # Test adding and deleting a file in a gem with -p0 option

  def test_delete_file_patch
    gemfile = bake_testing_gem

    patches = []
    patches << bake_new_file_patch
    patches << bake_delete_file_patch

    # Create a new patched gem in @gems_fir
    patcher = Gem::Patcher.new(gemfile, @gems_dir)
    patched_gem = patcher.patch_with(patches, 0)

    # Unpack
    package = Gem::Package.new patched_gem
    package.extract_files @gems_dir

    # Only foo.rb should stay in /lib, bar.rb should be gone
    assert_raises(RuntimeError, 'File not found') {
      file_contents(File.join @lib_dir, 'bar.rb')
    }
  end

  ##
  # Incorrect patch, nothing happens

  def test_gem_should_not_change
    gemfile = bake_testing_gem

    patches = []
    patches << bake_incorrect_patch

    # Create a new patched gem in @gems_fir
    patcher = Gem::Patcher.new(gemfile, @gems_dir)
    patched_gem = patcher.patch_with(patches, 0)

    # Unpack
    package = Gem::Package.new patched_gem
    package.extract_files @gems_dir

    assert_equal original_file, file_contents('foo.rb')
    assert_equal original_gemspec, current_gemspec
  end

  def bake_change_file_patch
    patch_path = File.join(@gems_dir, 'change_file.patch')

    File.open(patch_path, 'w') do |f|
      f.write change_file_patch
    end

    patch_path
  end

  def bake_new_file_patch
    patch_path = File.join(@gems_dir, 'new_file.patch')

    File.open(patch_path, 'w') do |f|
      f.write new_file_patch
    end

    patch_path
  end

  def bake_delete_file_patch
    patch_path = File.join(@gems_dir, 'delete_file.patch')

    File.open(patch_path, 'w') do |f|
      f.write delete_file_patch
    end

    patch_path
  end

  def bake_incorrect_patch
    patch_path = File.join(@gems_dir, 'incorrect.patch')

    File.open(patch_path, 'w') do |f|
      f.write incorrect_patch
    end

    patch_path
  end

  def bake_original_gem_files
    # Create /lib/foo.rb
    file_path = File.join(@lib_dir, 'foo.rb')

    File.open(file_path, 'w') do |f|
      f.write original_file
    end

    # Create .gemspec file
    gemspec_path = File.join(@gems_dir, 'foo-0.gemspec')

    File.open(gemspec_path, 'w') do |f|
      f.write original_gemspec
    end
  end

  def bake_testing_gem
    bake_original_gem_files

    test_package = Gem::Package.new 'foo-0.gem'
    test_package.spec = Gem::Specification.load(File.join(@gems_dir, 'foo-0.gemspec'))

    # Build 
    Dir.chdir @gems_dir do
      test_package.build false
    end

    File.join(@gems_dir, 'foo-0.gem')
  end

  def current_gemspec
    gemspec_path = File.join(@gems_dir, 'foo-0.gemspec')
    
    IO.read(gemspec_path)
  end

  ##
  # Get the content of the given file in @lib_dir

  def file_contents(file)
    file_path = File.join(@lib_dir, file)

    begin
      file_content = IO.read(file_path)
    rescue 
      raise RuntimeError, 'File not found'
    end

    file_content
  end

  def original_gemspec
    <<-EOF
      Gem::Specification.new do |s|
        s.platform = Gem::Platform::RUBY
        s.name = 'foo'
        s.version = 0
        s.author = 'A User'
        s.email = 'example@example.com'
        s.homepage = 'http://example.com'
        s.summary = "this is a summary"
        s.description = "This is a test description"
        s.files = ['lib/foo.rb']
      end
    EOF
  end

  def original_file
    <<-EOF
      module Foo
        def bar
          'Original'
        end
      end
    EOF
  end

  def patched_file
    <<-EOF
      module Foo
        class Bar
          def foo_bar
            'Patched'
          end
        end
      end
    EOF
  end

  def change_file_patch
    <<-EOF
      diff -u a/lib/foo.rb b/lib/foo.rb
      --- a/lib/foo.rb 
      +++ b/lib/foo.rb
      @@ -1,6 +1,8 @@
             module Foo
      -        def bar
      -          'Original'
      +        class Bar
      +          def foo_bar
      +            'Patched'
      +          end
               end
            end
    EOF
  end

  def new_file_patch
    <<-EOF
      diff lib/bar.rb lib/bar.rb
      --- /dev/null
      +++ lib/bar.rb
      @@ -0,0 +1,5 @@
      +      module Foo
      +        def bar
      +          'Original'
      +        end
      +      end
    EOF
  end

  def delete_file_patch
    <<-EOF
      diff lib/bar.rb lib/bar.rb
      --- lib/bar.rb
      +++ /dev/null
      @@ -1,5 +0,0 @@
      -      module Foo
      -        def bar
      -          'Original'
      -        end
      -      end
    EOF
  end

  def incorrect_patch
    <<-EOF
      diff lib/foo.rb lib/foo.rb
      --- lib/foo.rb
      +++ /dev/null
      -      module Foo
      -        def bar
      -          'Original'
      -        end
      -      end
    EOF
  end
end