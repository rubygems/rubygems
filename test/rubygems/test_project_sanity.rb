# frozen_string_literal: true

require "open3"

class TestProjectSanity < Minitest::Test

  def test_manifest_is_up_to_date
    skip unless File.exist?(File.expand_path("../../../Rakefile", __FILE__))
    # ruby/ruby testing
    skip if ENV['CORE_CI']

    _, status = Open3.capture2e("rake check_manifest")

    assert status.success?, "Expected Manifest.txt to be up to date, but it's not. Run `rake update_manifest` to sync it."
  end

end
