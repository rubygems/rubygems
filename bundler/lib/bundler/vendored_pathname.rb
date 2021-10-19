# frozen_string_literal: true

#
# Pure ruby implementation of the C-extension of the `pathname` gem.
#
module Bundler
  def Pathname(str) # rubocop:disable Naming/MethodName
    return str if str.is_a?(Bundler::Pathname)

    Pathname.new(str)
  end
  module_function :Pathname

  class Pathname
    attr_reader :path

    def initialize(path)
      path = path.to_path if path.respond_to? :to_path

      @path = String.new(path)
    end

    def eql?(other)
      self.class == other.class && path == other.path
    end

    alias_method :==, :eql?

    def hash
      path.hash
    end

    def to_s
      path
    end

    alias_method :to_path, :to_s

    def sub(*args, &block)
      self.class.new(path.sub(*args), &block)
    end

    def read(*args)
      File.read(path, *args)
    end

    def open(mode, &block)
      File.open(path, mode, &block)
    end

    def basename
      self.class.new(File.basename(path))
    end

    def dirname
      self.class.new(File.dirname(path))
    end

    def expand_path(base = Dir.pwd)
      self.class.new(File.expand_path(path, base))
    end

    def exist?
      File.exist?(path)
    end

    def directory?
      File.directory?(path)
    end

    def file?
      File.file?(path)
    end

    def size
      File.size(path)
    end
  end
end

require_relative "vendor/pathname/lib/pathname"
