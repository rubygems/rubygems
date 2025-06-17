# frozen_string_literal: true

##
# Manylinux support for Ruby platform detection, inspired by Python's packaging system.
# This module implements logic to detect glibc version for generating compatible manylinux platform tags.
#
# Based on Python's packaging._manylinux
# https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py

module Gem::Platform::Manylinux
  module_function

  # glibc version detection for manylinux support
  # Based on Python's packaging._manylinux._get_glibc_version
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py#L172-L177
  def glibc_version
    return @glibc_version if defined?(@glibc_version)

    # Try confstr method first (faster and more reliable)
    version_str = glibc_version_string_confstr
    version_str ||= glibc_version_string_ctypes

    @glibc_version = version_str ? parse_glibc_version(version_str) : nil
  end

  def glibc_version_string_confstr
    # Ruby equivalent of Python's os.confstr approach
    # Based on Python's packaging._manylinux._glibc_version_string_confstr
    # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py#L85-L101
    begin
      # CS_GNU_LIBC_VERSION might not be defined on all systems
      return nil unless defined?(Etc::CS_GNU_LIBC_VERSION)

      version_string = Etc.confstr(Etc::CS_GNU_LIBC_VERSION)

      # Should return something like "glibc 2.17"
      return version_string if version_string&.include?("glibc")
    rescue LoadError, SystemCallError, ArgumentError
      # Etc not available, confstr not supported, CS_GNU_LIBC_VERSION not supported
    end

    nil
  end

  def glibc_version_string_ctypes
    # Ruby equivalent of Python's ctypes approach to get glibc version
    # Based on Python's packaging._manylinux._glibc_version_string_ctypes
    # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py#L104-L149

    # Try to get version from ldd --version (most reliable)
    begin
      output = Gem::Util.popen("ldd", "--version", { err: [:child, :out] })
      if output.match?(/glibc|GNU libc/i)
        # Look for version pattern like "ldd (GNU libc) 2.17" or "glibc 2.17"
        if match = output.match(/(?:glibc|GNU libc|libc).*?(\d+\.\d+)/i)
          return match[1]
        end
      end
    rescue StandardError
      # Ignore errors and try alternative method
    end

    # Try to get version from GNU libc shared library directly
    begin
      # Common libc.so.6 locations
      libc_paths = [
        "/lib/libc.so.6",
        "/lib64/libc.so.6",
        "/lib/x86_64-linux-gnu/libc.so.6",
        "/lib/aarch64-linux-gnu/libc.so.6",
      ]

      libc_paths.each do |path|
        next unless File.exist?(path)

        output = Gem::Util.popen(path, { err: [:child, :out] })
        if match = output.match(/GNU C Library.*?version (\d+\.\d+)/i)
          return match[1]
        end
      end
    rescue StandardError
      # Ignore errors
    end

    nil
  end

  # Based on Python's packaging._manylinux._parse_glibc_version
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py#L153-L169
  def parse_glibc_version(version_str)
    if match = version_str.match(/^(\d+)\.(\d+)/)
      [match[1].to_i, match[2].to_i]
    end
  end

  # Generate manylinux tags for given architectures
  # Based on Python's packaging._manylinux.platform_tags
  # https://github.com/pypa/packaging/blob/0055d4b56ae868bbcc7825c9ad68f49cdcb9f8b9/src/packaging/_manylinux.py#L217-L261
  def platform_tags(archs, glibc_ver)
    return enum_for(__method__, archs, glibc_ver) unless block_given?

    major, minor = glibc_ver
    return if major < 2 # glibc must be at least 2.x

    archs.each do |arch|
      # Generate compatible glibc versions from current down to minimum
      min_minor = arch.match?(/^(x86_64|i686)$/) ? 5 : 17 # x86/i686 supports older glibc

      major.downto(2) do |maj|
        max_min = maj == major ? minor : 50 # Assume max minor version
        start_minor = maj == 2 && min_minor > 0 ? [max_min, min_minor].max : max_min

        start_minor.downto(maj == 2 ? [min_minor, 0].max : 0) do |min|
          yield "manylinux_#{maj}_#{min}_#{arch}"
        end
      end
    end
  end
end
