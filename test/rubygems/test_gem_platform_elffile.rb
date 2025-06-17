# frozen_string_literal: true

require_relative "helper"
require "rubygems/platform/elffile"

class TestGemPlatformELFFile < Gem::TestCase
  def setup
    super

    # Paths to test ELF files from Python's packaging repository
    @packaging_tests_dir = "/Users/segiddins/Development/github.com/pypa/packaging/tests"
    @manylinux_dir = File.join(@packaging_tests_dir, "manylinux")
    @musllinux_dir = File.join(@packaging_tests_dir, "musllinux")

    pend "Python packaging test files not available" unless File.directory?(@packaging_tests_dir)
  end

  def test_elffile_glibc_files
    test_cases = [
      ["hello-world-x86_64-i386", 32, :little_endian],
      ["hello-world-x86_64-amd64", 64, :little_endian],
      ["hello-world-armv7l-armel", 32, :little_endian],
      ["hello-world-armv7l-armhf", 32, :little_endian],
      ["hello-world-s390x-s390x", 64, :big_endian],
    ]

    test_cases.each do |name, expected_bits, expected_endian|
      path = File.join(@manylinux_dir, name)

      reader = Gem::Platform::ELFFile::Reader.new(path)

      # Test that we can read the file without errors
      refute_nil reader, "Should be able to create reader for #{name}"

      # Verify bit width detection
      if expected_bits == 64
        assert reader.instance_variable_get(:@is_64bit), "#{name} should be detected as 64-bit"
      else
        refute reader.instance_variable_get(:@is_64bit), "#{name} should be detected as 32-bit"
      end

      # Verify endianness detection
      if expected_endian == :little_endian
        assert reader.instance_variable_get(:@is_little_endian), "#{name} should be little endian"
      else
        refute reader.instance_variable_get(:@is_little_endian), "#{name} should be big endian"
      end

      # Verify it's a valid ELF file
      assert reader.send(:valid_elf?), "#{name} should be valid ELF"
    end
  end

  def test_elffile_musl_files
    test_cases = [
      ["musl-aarch64", 64, :little_endian, "/lib/ld-musl-aarch64.so.1"],
      ["musl-i386", 32, :little_endian, "/lib/ld-musl-i386.so.1"],
      ["musl-x86_64", 64, :little_endian, "/lib/ld-musl-x86_64.so.1"],
    ]

    test_cases.each do |name, expected_bits, expected_endian, expected_interpreter|
      path = File.join(@musllinux_dir, name)

      reader = Gem::Platform::ELFFile::Reader.new(path)

      # Test interpreter extraction
      assert_equal expected_interpreter, reader.interpreter, "#{name} should have correct interpreter"

      # Test bit width
      if expected_bits == 64
        assert reader.instance_variable_get(:@is_64bit), "#{name} should be 64-bit"
      else
        refute reader.instance_variable_get(:@is_64bit), "#{name} should be 32-bit"
      end

      # Test endianness
      if expected_endian == :little_endian
        assert reader.instance_variable_get(:@is_little_endian), "#{name} should be little endian"
      else
        refute reader.instance_variable_get(:@is_little_endian), "#{name} should be big endian"
      end
    end
  end

  def test_elffile_module_function
    # Test the module-level interpreter function
    musl_x86_64_path = File.join(@musllinux_dir, "musl-x86_64")

    interpreter = Gem::Platform::ELFFile.interpreter(musl_x86_64_path)
    assert_equal "/lib/ld-musl-x86_64.so.1", interpreter
  end

  def test_elffile_bad_magic
    # Test with various invalid ELF files
    invalid_files = [
      "hello-world-invalid-magic",
      "hello-world-too-short",
    ]

    invalid_files.each do |name|
      path = File.join(@manylinux_dir, name)

      # Should not raise an exception, but should return nil interpreter
      reader = Gem::Platform::ELFFile::Reader.new(path)
      assert_nil reader.interpreter, "#{name} should have nil interpreter"
      refute reader.send(:valid_elf?), "#{name} should not be valid ELF"
    end
  end

  def test_elffile_nonexistent_file
    # Test with non-existent file
    interpreter = Gem::Platform::ELFFile.interpreter("/nonexistent/file")
    assert_nil interpreter, "Non-existent file should return nil"
  end

  def test_elffile_truncated_file
    # Test with truncated ELF file (simulating incomplete read)
    musl_x86_64_path = File.join(@musllinux_dir, "musl-x86_64")

    # Create a truncated version (just the header)
    original_data = File.read(musl_x86_64_path, mode: "rb")
    truncated_data = original_data[0, 58] # Just enough for header, not sections

    Tempfile.create(["truncated", ".elf"]) do |tmpfile|
      tmpfile.write(truncated_data)
      tmpfile.close

      reader = Gem::Platform::ELFFile::Reader.new(tmpfile.path)
      # Should handle gracefully and return nil interpreter
      assert_nil reader.interpreter, "Truncated file should have nil interpreter"
    end
  end

  def test_elffile_current_ruby_executable
    pend "current ruby will only have an interpreter on linux" unless RUBY_PLATFORM.include?("linux")

    # Test with the current Ruby executable
    ruby_path = RbConfig.ruby

    # This should work without raising an exception
    interpreter = Gem::Platform::ELFFile.interpreter(ruby_path)

    # On Linux, we expect some interpreter (either glibc or musl)
    assert_match(%r{^/lib}, interpreter)
  end

  def test_elffile_constants
    # Test that constants are defined correctly
    assert_equal 0x7f, Gem::Platform::ELFFile::ELFMAG0
    assert_equal 0x45, Gem::Platform::ELFFile::ELFMAG1  # 'E'
    assert_equal 0x4c, Gem::Platform::ELFFile::ELFMAG2  # 'L'
    assert_equal 0x46, Gem::Platform::ELFFile::ELFMAG3  # 'F'

    assert_equal 1, Gem::Platform::ELFFile::ELFCLASS32
    assert_equal 2, Gem::Platform::ELFFile::ELFCLASS64

    assert_equal 1, Gem::Platform::ELFFile::ELFDATA2LSB  # Little endian
    assert_equal 2, Gem::Platform::ELFFile::ELFDATA2MSB  # Big endian

    assert_equal 3, Gem::Platform::ELFFile::PT_INTERP
  end
end
