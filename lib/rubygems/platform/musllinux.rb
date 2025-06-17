# frozen_string_literal: true

##
# Musllinux support for Ruby platform detection, inspired by Python's packaging system.
# This module implements logic to detect musl version for generating compatible musllinux platform tags.
#
# Based on Python's packaging._musllinux
# https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_musllinux.py

require_relative "elffile"

module Gem::Platform::Musllinux
  module_function

  # musl version detection for musllinux support
  # Based on Python's packaging._musllinux._get_musl_version
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_musllinux.py#L33-L53
  def musl_version
    return @musl_version if defined?(@musl_version)

    @musl_version = detect_musl_version
  end

  # Detect musl version using ELF parsing approach like Python
  # Based on Python's packaging._musllinux._get_musl_version
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_musllinux.py#L33-L53
  def detect_musl_version
    # Get current Ruby executable path
    executable = RbConfig.ruby

    # Extract ELF interpreter path
    interpreter = Gem::Platform::ELFFile.interpreter(executable)
    return nil unless interpreter&.include?("musl")

    # Execute the interpreter to get version info
    begin
      # Run the musl interpreter which prints version to stderr
      result = Gem::Util.popen(interpreter, { err: [:child, :out] })
      parse_musl_version(result)
    rescue StandardError
      # Fallback to ldd-based detection if ELF parsing fails
      fallback_musl_detection
    end
  end

  # Parse musl version from interpreter output
  # Based on Python's packaging._musllinux._parse_musl_version
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_musllinux.py#L23-L30
  def parse_musl_version(output)
    lines = output.strip.split("\n")
    return nil if lines.empty?

    # First line should start with "musl libc"
    first_line = lines[0]
    return nil unless first_line&.start_with?("musl")

    # Look for version in format "Version X.Y" in any line
    lines.each do |line|
      if match = line.match(/Version (\d+)\.(\d+)/i)
        return [match[1].to_i, match[2].to_i]
      end
    end

    nil
  end

  # Fallback musl detection when ELF parsing fails
  def fallback_musl_detection
    # Try to get musl version from ldd output
    begin
      output = Gem::Util.popen("ldd", "--version", { err: [:child, :out] })
      if output.match?(/musl/i)
        # Look for version pattern like "musl libc (x86_64) Version 1.2.2"
        if match = output.match(/Version (\d+)\.(\d+)/i)
          return [match[1].to_i, match[2].to_i]
        end
      end
    rescue StandardError
      # Ignore errors
    end

    # Try alternative detection methods
    begin
      # Check if we can find musl ld.so and execute it
      musl_loaders = Dir.glob("/lib/ld-musl-*.so.1") + Dir.glob("/usr/lib/ld-musl-*.so.1")

      musl_loaders.each do |loader|
        next unless File.executable?(loader)

        output = Gem::Util.popen(loader, { err: [:child, :out] })
        if match = output.match(/Version (\d+)\.(\d+)/i)
          return [match[1].to_i, match[2].to_i]
        end
      end
    rescue StandardError
      # Ignore errors
    end

    nil
  end

  def musl_system?
    # Use ELF parsing approach like Python to detect musl
    executable = RbConfig.ruby
    interpreter = Gem::Platform::ELFFile.interpreter(executable)

    return true if interpreter&.include?("musl")

    # Fallback to traditional detection methods
    return true if Dir.glob("/lib/ld-musl-*.so.1").any?
    return true if Dir.glob("/usr/lib/ld-musl-*.so.1").any?

    # Check ldd version for musl signature
    begin
      output = Gem::Util.popen("ldd", "--version", { err: [:child, :out] })
      return true if output.match?(/musl/i)
    rescue StandardError
      # Ignore errors
    end

    false
  end

  # Generate musllinux tags for given architectures
  # Based on Python's packaging._musllinux.platform_tags
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_musllinux.py#L56-L72
  def platform_tags(archs, musl_ver)
    return enum_for(__method__, archs, musl_ver) unless block_given?

    major, minor = musl_ver

    archs.each do |arch|
      # Generate compatible musl versions from current down to 0
      minor.downto(0) do |min|
        yield "musllinux_#{major}_#{min}_#{arch}"
      end
    end
  end
end
