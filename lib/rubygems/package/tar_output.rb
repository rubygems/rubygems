#++
# Copyright (C) 2004 Mauricio Julio Fernández Pradier
# See LICENSE.txt for additional licensing information.
#--

require 'rubygems/package'

class Gem::Package::TarOutput

  private_class_method :new

  def self.open(filename, signer = nil, &block)
    io = File.open filename, "wb"
    open_from_io(io, signer, &block)
    nil
  end

  def self.open_from_io(io, signer = nil, &block)
    outputter = new io
    metadata = nil
    set_meta = lambda { |x| metadata = x }

    raise "Want a block" unless block_given?

    begin
      data_sig, meta_sig = nil, nil

      outputter.external_handle.add_file("data.tar.gz", 0644) do |inner|
        begin
          sio = signer ? StringIO.new : nil
          os = Zlib::GzipWriter.new(sio || inner)

          Gem::Package::TarWriter.new(os) do |inner_tar_stream|
            klass = class << inner_tar_stream; self end
            klass.send(:define_method, :metadata=, &set_meta)
            block.call inner_tar_stream
          end
        ensure
          os.flush
          os.finish
          #os.close

          # if we have a signing key, then sign the data
          # digest and return the signature
          data_sig = nil
          if signer
            dgst_algo = Gem::Security::OPT[:dgst_algo]
            dig = dgst_algo.digest(sio.string)
            data_sig = signer.sign(dig)
            inner.write(sio.string)
          end
        end
      end

      # if we have a data signature, then write it to the gem too
      if data_sig
        sig_file = 'data.tar.gz.sig'
        outputter.external_handle.add_file(sig_file, 0644) do |os|
          os.write(data_sig)
        end
      end

      outputter.external_handle.add_file("metadata.gz", 0644) do |os|
        begin
          sio = signer ? StringIO.new : nil
          gzos = Zlib::GzipWriter.new(sio || os)
          gzos.write metadata
        ensure
          gzos.flush
          gzos.finish

          # if we have a signing key, then sign the metadata
          # digest and return the signature
          if signer
            dgst_algo = Gem::Security::OPT[:dgst_algo]
            dig = dgst_algo.digest(sio.string)
            meta_sig = signer.sign(dig)
            os.write(sio.string)
          end
        end
      end

      # if we have a metadata signature, then write to the gem as
      # well
      if meta_sig
        sig_file = 'metadata.gz.sig'
        outputter.external_handle.add_file(sig_file, 0644) do |os|
          os.write(meta_sig)
        end
      end

    ensure
      outputter.close
    end

    nil
  end

  def initialize(io)
    @io = io
    @external = Gem::Package::TarWriter.new @io
  end

  def close
    @external.close
    @io.close
  end

  def external_handle
    @external
  end

end

