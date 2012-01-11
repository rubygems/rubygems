require 'rubygems/package/tar_test_case'
require 'rubygems/simple_gem'

class TestGemPackage < Gem::Package::TarTestCase

  def setup
    super

    @spec = quick_gem 'a' do |s|
      s.files = %w[lib/code.rb]
    end

    util_build_gem @spec

    @gem = @spec.cache_file

    @destination = File.join @tempdir, 'extract'
  end

  def test_class_new_old_format
    open 'old_format.gem', 'wb' do |io|
      io.write SIMPLE_GEM
    end

    package = Gem::Package.new 'old_format.gem'

    assert package.spec
  end

  def test_add_files
    spec = Gem::Specification.new
    spec.files = 'lib/code.rb'

    FileUtils.mkdir 'lib'
    open 'lib/code.rb',  'w' do |io| io.write '# lib/code.rb'  end
    open 'lib/extra.rb', 'w' do |io| io.write '# lib/extra.rb' end

    package = Gem::Package.new 'bogus.gem'
    package.spec = spec

    tar = util_tar do |tar_io|
      package.add_files tar_io
    end

    tar.rewind

    files = []

    Gem::Package::TarReader.new tar do |tar_io|
      tar_io.each_entry do |entry|
        files << entry.full_name
      end
    end

    assert_equal %w[lib/code.rb], files
  end

  def test_build
    spec = Gem::Specification.new 'build', '1'
    spec.summary = 'build'
    spec.authors = 'build'
    spec.files = ['lib/code.rb']

    FileUtils.mkdir 'lib'

    open 'lib/code.rb', 'w' do |io|
      io.write '# lib/code.rb'
    end

    package = Gem::Package.new spec.file_name
    package.spec = spec

    package.build

    assert_equal Gem::VERSION, spec.rubygems_version
    assert_path_exists spec.file_name

    reader = Gem::Package.new spec.file_name
    assert_equal spec, reader.spec

    assert_equal %w[metadata.gz metadata.gz.sum data.tar.gz data.tar.gz.sum],
                 reader.files

    assert_equal %w[lib/code.rb], reader.contents
  end

  def test_build_invalid
    spec = Gem::Specification.new 'build', '1'

    package = Gem::Package.new spec.file_name
    package.spec = spec

    e = assert_raises Gem::InvalidSpecificationException do
      package.build
    end

    assert_equal 'missing value for attribute summary', e.message
  end

  def test_build_signed
    spec = Gem::Specification.new 'build', '1'
    spec.summary = 'build'
    spec.authors = 'build'
    spec.files = ['lib/code.rb']
    spec.cert_chain = [PUBLIC_CERT.to_pem]
    spec.signing_key = PRIVATE_KEY

    FileUtils.mkdir 'lib'

    open 'lib/code.rb', 'w' do |io|
      io.write '# lib/code.rb'
    end

    package = Gem::Package.new spec.file_name
    package.spec = spec

    package.build

    assert_equal Gem::VERSION, spec.rubygems_version
    assert_path_exists spec.file_name

    reader = Gem::Package.new spec.file_name
    assert reader.verify

    assert_equal spec, reader.spec

    assert_equal %w[metadata.gz metadata.gz.sum metadata.gz.sig
                    data.tar.gz data.tar.gz.sum data.tar.gz.sig],
                 reader.files

    assert_equal %w[lib/code.rb], reader.contents
  end

  def test_contents
    package = Gem::Package.new @gem

    assert_equal %w[lib/code.rb], package.contents
  end

  def test_extract_files
    package = Gem::Package.new @gem

    package.extract_files @destination

    extracted = File.join @destination, 'lib/code.rb'
    assert_path_exists extracted

    mask = 0100644 & (~File.umask)

    assert_equal mask, File.stat(extracted).mode unless win_platform?
  end

  def test_extract_files_empty
    data_tgz = util_tar_gz do end

    gem = util_tar do |tar|
      tar.add_file 'data.tar.gz', 0644 do |io|
        io.write data_tgz.string
      end

      tar.add_file 'metadata.gz', 0644 do |io|
        Zlib::GzipWriter.wrap io do |gzio|
          gzio.write @spec.to_yaml
        end
      end
    end

    open 'empty.gem', 'wb' do |io|
      io.write gem.string
    end

    package = Gem::Package.new 'empty.gem'

    package.extract_files @destination

    assert_path_exists @destination
  end

  def test_extract_tar_gz_absolute
    package = Gem::Package.new @gem

    tgz_io = util_tar_gz do |tar|
      tar.add_file '/absolute.rb', 0644 do |io| io.write 'hi' end
    end

    e = assert_raises Gem::Package::PathError do
      package.extract_tar_gz tgz_io, @destination
    end

    assert_equal("installing into parent path /absolute.rb of " \
                 "#{@destination} is not allowed", e.message)
  end

  def test_install_location
    package = Gem::Package.new @gem

    file = 'file.rb'
    file.taint

    destination = package.install_location file, @destination

    assert_equal File.join(@destination, 'file.rb'), destination
    refute destination.tainted?
  end

  def test_install_location_absolute
    package = Gem::Package.new @gem

    e = assert_raises Gem::Package::PathError do
      package.install_location '/absolute.rb', @destination
    end

    assert_equal("installing into parent path /absolute.rb of " \
                 "#{@destination} is not allowed", e.message)
  end

  def test_install_location_relative
    package = Gem::Package.new @gem

    e = assert_raises Gem::Package::PathError do
      package.install_location '../relative.rb', @destination
    end

    parent = File.expand_path File.join @destination, "../relative.rb"

    assert_equal("installing into parent path #{parent} of " \
                 "#{@destination} is not allowed", e.message)
  end

  def test_verify
    package = Gem::Package.new @gem

    package.verify

    assert_equal @spec, package.spec
    assert_equal %w[data.tar.gz data.tar.gz.sum metadata.gz metadata.gz.sum],
                 package.files.sort
  end

  def test_verify_checksum_bad
    data_tgz = util_tar_gz do |tar|
      tar.add_file 'lib/code.rb', 0444 do |io|
        io.write '# lib/code.rb'
      end
    end

    data_tgz = data_tgz.string

    gem = util_tar do |tar|
      metadata_gz = Gem.gzip @spec.to_yaml

      tar.add_file 'metadata.gz', 0444 do |io|
        io.write metadata_gz
      end

      digest = OpenSSL::Digest::SHA1.new
      digest << metadata_gz
      digest << 'bogus'
      checksum = "#{digest.name}\t#{digest.hexdigest}\n"

      tar.add_file 'metadata.gz.sum', 0444 do |io|
        io.write checksum
      end

      tar.add_file 'data.tar.gz', 0444 do |io|
        io.write data_tgz
      end

      digest = OpenSSL::Digest::SHA1.new
      digest << data_tgz
      digest << 'bogus'
      checksum = "#{digest.name}\t#{digest.hexdigest}\n"

      tar.add_file 'data.tar.gz.sum', 0444 do |io|
        io.write checksum
      end
    end

    open 'mismatch.gem', 'wb' do |io|
      io.write gem.string
    end

    package = Gem::Package.new 'mismatch.gem'

    e = assert_raises Gem::Package::FormatError do
      package.verify
    end

    assert_equal 'checksum mismatch for data.tar.gz in mismatch.gem', e.message
  end

  def test_verify_checksum_missing
    data_tgz = util_tar_gz do |tar|
      tar.add_file 'lib/code.rb', 0444 do |io|
        io.write '# lib/code.rb'
      end
    end

    data_tgz = data_tgz.string

    gem = util_tar do |tar|
      metadata_gz = Gem.gzip @spec.to_yaml

      tar.add_file 'metadata.gz', 0444 do |io|
        io.write metadata_gz
      end

      digest = OpenSSL::Digest::SHA1.new
      digest << metadata_gz
      checksum = "#{digest.name}\t#{digest.hexdigest}\n"

      tar.add_file 'metadata.gz.sum', 0444 do |io|
        io.write checksum
      end

      tar.add_file 'data.tar.gz', 0444 do |io|
        io.write data_tgz
      end
    end

    open 'data_checksum_missing.gem', 'wb' do |io|
      io.write gem.string
    end

    package = Gem::Package.new 'data_checksum_missing.gem'

    assert package.verify
  end

  def test_verify_corrupt
    Tempfile.open 'corrupt' do |io|
      data = Gem.gzip 'a' * 10
      io.write tar_file_header('metadata.gz', "\000x", 0644, data.length)
      io.write data
      io.rewind

      package = Gem::Package.new io.path

      e = assert_raises Gem::Package::FormatError do
        package.verify
      end

      assert_equal "tar is corrupt, name contains null byte in #{io.path}",
                   e.message
    end
  end

  def test_verify_empty
    FileUtils.touch 'empty.gem'

    package = Gem::Package.new 'empty.gem'

    e = assert_raises Gem::Package::FormatError do
      package.verify
    end

    assert_equal 'package metadata is missing in empty.gem', e.message
  end

  def test_verify_nonexistent
    package = Gem::Package.new 'nonexistent.gem'

    e = assert_raises Gem::Package::FormatError do
      package.verify
    end

    assert_equal 'No such file or directory - nonexistent.gem', e.message
  end

  def test_verify_security_policy
    package = Gem::Package.new @gem
    package.security_policy = Gem::Security::HighSecurity

    e = assert_raises Gem::Security::Exception do
      package.verify
    end

    assert_equal 'unsigned gems are not allowed by the High Security policy',
                 e.message
  end

  def test_verify_truncate
    open 'bad.gem', 'wb' do |io|
      io.write File.read(@gem, 1024) # don't care about newlines
    end

    package = Gem::Package.new 'bad.gem'

    e = assert_raises Gem::Package::FormatError do
      package.verify
    end

    assert_equal 'package content (data.tar.gz) is missing in bad.gem',
                 e.message
  end

  def test_verify_signatures
    Gem::Security.add_trusted_cert PUBLIC_CERT

    digest = Gem::Security::OPT[:dgst_algo]

    @spec.cert_chain = [PUBLIC_CERT.to_s]

    metadata_gz = Gem.gzip @spec.to_yaml

    package = Gem::Package.new @gem
    package.spec = @spec
    package.security_policy = Gem::Security::HighSecurity

    metadata_gz_digest = package.digest StringIO.new metadata_gz

    digests = {}
    digests['metadata.gz'] = metadata_gz_digest

    signatures = {}
    signatures['metadata.gz'] =
      PRIVATE_KEY.sign digest.new, metadata_gz_digest.digest

    package.verify_signatures digests, signatures
  end

  def test_verify_signatures_missing
    Gem::Security.add_trusted_cert PUBLIC_CERT

    digest = Gem::Security::OPT[:dgst_algo]

    @spec.cert_chain = [PUBLIC_CERT.to_s]

    metadata_gz = Gem.gzip @spec.to_yaml

    package = Gem::Package.new @gem
    package.spec = @spec
    package.security_policy = Gem::Security::HighSecurity

    metadata_gz_digest = package.digest StringIO.new metadata_gz

    digests = {}
    digests['metadata.gz'] = metadata_gz_digest
    digests['data.tar.gz'] = package.digest StringIO.new 'hello' # fake

    signatures = {}
    signatures['metadata.gz'] =
      PRIVATE_KEY.sign digest.new, metadata_gz_digest.digest

    e = assert_raises Gem::Security::Exception do
      package.verify_signatures digests, signatures
    end

    assert_equal 'missing signature for data.tar.gz', e.message
  end

  def test_spec
    package = Gem::Package.new @gem

    assert_equal @spec, package.spec
  end

  def util_tar
    tar_io = StringIO.new

    Gem::Package::TarWriter.new tar_io do |tar|
      yield tar
    end

    tar_io.rewind

    tar_io
  end

  def util_tar_gz(&block)
    tar_io = util_tar(&block)

    tgz_io = StringIO.new

    # can't wrap TarWriter because it seeks
    Zlib::GzipWriter.wrap tgz_io do |io| io.write tar_io.string end

    StringIO.new tgz_io.string
  end

end

