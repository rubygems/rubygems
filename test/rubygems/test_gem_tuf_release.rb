require 'rubygems/test_case'
require 'rubygems/command'
require 'rubygems/tuf'

class TestRelease < Gem::TestCase
  def setup
    super
  end

  def test_verifies_good_release
    root    = Gem::TUF::Root.new File.read(File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
    release = Gem::TUF::Release.new(root, File.read( File.join(ENV['PWD'], 'test/rubygems/tuf/release.txt')))
    assert release
  end

  def test_rejects_bad_release
    root    = Gem::TUF::Root.new File.read(File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
    assert_raises Gem::TUF::VerificationError do
      Gem::TUF::Release.new(root, File.read( File.join(ENV['PWD'], 'test/rubygems/tuf/bad_release.txt')))
    end
  end

  def test_has_targets
    root    = Gem::TUF::Root.new File.read(File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
    release = Gem::TUF::Release.new(root, File.read( File.join(ENV['PWD'], 'test/rubygems/tuf/release.txt')))
    assert release.targets["hashes"]["sha512"]
    assert release.targets["length"]
  end

  def test_does_not_need_to_update_root
    root    = Gem::TUF::Root.new File.read(File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
    release = Gem::TUF::Release.new(root, File.read( File.join(ENV['PWD'], 'test/rubygems/tuf/release.txt')))

    assert_equal false,
      release.should_update_root?(File.read File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
  end

  def test_needs_to_update_root
    root    = Gem::TUF::Root.new File.read(File.join(ENV['PWD'], 'test/rubygems/tuf/root.txt'))
    release = Gem::TUF::Release.new(root, File.read( File.join(ENV['PWD'], 'test/rubygems/tuf/release.txt')))

    assert release.should_update_root?("")
  end
end
