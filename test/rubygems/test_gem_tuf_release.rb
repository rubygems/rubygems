require 'rubygems/test_case'
require 'rubygems/command'
require 'rubygems/tuf'

class TestRelease < Gem::TestCase
  def setup
    super
  end

  ROOT_FILE = tuf_file 'root.txt'
  RELEASE_FILE = tuf_file 'release.txt'
  BAD_RELEASE_FILE = tuf_file 'bad_release.txt'

  def release
    root    = Gem::TUF::Root.new File.read(ROOT_FILE)
    Gem::TUF::Release.new(root, File.read(RELEASE_FILE))
  end

  def test_verifies_good_release
    assert release
  end

  def test_rejects_bad_release
    root    = Gem::TUF::Root.new File.read(ROOT_FILE)
    assert_raises Gem::TUF::VerificationError do
      Gem::TUF::Release.new(root, File.read(BAD_RELEASE_FILE))
    end
  end

  def test_has_targets
    assert release.targets["hashes"]["sha512"]
    assert release.targets["length"]
  end

  def test_does_not_need_to_update_root
    assert_equal false, release.should_update_root?(File.read ROOT_FILE)
  end

  def test_needs_to_update_root
    assert release.should_update_root?("not the correct digest")
  end
end
