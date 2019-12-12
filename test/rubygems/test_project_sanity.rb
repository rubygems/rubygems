# frozen_string_literal: true

require "rubygems/test_case"
require "open3"

class TestProjectSanity < Minitest::Test

  def test_rake_package_builds_ok
    skip unless File.exist?(File.expand_path("../../../Rakefile", __FILE__))

    with_empty_pkg_folder do
      output, status = Open3.capture2e("rake package")

      assert_equal true, status.success?, <<~MSG.chomp
        Expected `rake package` to work, but got errors:

        ```
        #{output}
        ```

        If you have added or removed files, make sure you run `rake update_manifest` to update the `Manifest.txt` accordingly
      MSG
    end
  end

  def test_manifest_is_up_to_date
    skip unless File.exist?(File.expand_path("../../../Rakefile", __FILE__))

    _, status = Open3.capture2e("rake check_manifest")

    assert status.success?, "Expected Manifest.txt to be up to date, but it's not. Run `rake update_manifest` to sync it."
  end

  def test_ruby_setup_rb_builds_ok
    output, status = Open3.capture2e("ruby setup.rb")

    assert_equal true, status.success?, <<~MSG.chomp
      Expected `ruby setup.rb` to work, but got errors:

      ```
      #{output}
      ```

      The content of bin/bundle is #{File.read("/home/runner/.rvm/rubies/ruby-head/bin/bundle") if File.exist?("/home/runner/.rvm/rubies/ruby-head/bin/bundle")}
    MSG
  end

  private

  def with_empty_pkg_folder
    if File.exist?("pkg")
      FileUtils.cp_r("pkg", "tmp")

      begin
        FileUtils.rm_rf("pkg")
        yield
      ensure
        FileUtils.rm_rf("pkg")
        FileUtils.cp_r("tmp/pkg", ".")
      end
    else
      Dir.mkdir("pkg")

      begin
        yield
      ensure
        FileUtils.rm_rf("pkg")
      end
    end
  end

end
