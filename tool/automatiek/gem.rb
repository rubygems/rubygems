# frozen_string_literal: true

# The MIT License (MIT)
#
# Copyright (c) 2015 Samuel E. Giddins
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "fileutils"

module Automatiek
  class Gem
    def initialize(gem_name, &block)
      @gem_name = gem_name
      @dependencies = []
      block.call(self) if block
    end

    def vendor!(version = nil)
      update(version || self.version)

      @dependencies.each do |dependency|
        dependency.vendor!
        dependency.namespace_files(vendor_lib)
      end

      namespace_files(vendor_lib)

      clean
    end

    def download=(opts = {}, &block)
      if block
        @download = block
      elsif github = opts.delete(:github)
        @download = lambda do |version|
          Dir.chdir File.dirname(vendor_lib) do
            `curl -L #{github}/archive/#{version}.tar.gz | tar -xz`
            unless $?.success?
              raise "Downloading & untarring #{gem_name} (#{version}) failed"
            end
            FileUtils.mv "#{github.split("/").last}-#{version.sub(/^v/, "")}", gem_name
          end
        end
      end
    end

    def dependency(name, &block)
      dep = self.class.new(name, &block)
      @dependencies << dep
    end

    attr_accessor :gem_name
    attr_accessor :namespace
    attr_accessor :prefix
    attr_accessor :vendor_lib
    attr_accessor :version
    attr_accessor :license_path

    def update(version)
      FileUtils.rm_rf vendor_lib
      @download.call(version)
    end

    def require_target
      @require_target ||= vendor_lib.sub(%r{^(.+?/)?lib/}, "") << "/lib"
    end

    def require_entrypoint
      @require_entrypoint ||= gem_name.tr("-", "/")
    end

    attr_writer :require_entrypoint

    def namespace_files(folder)
      files = Dir.glob("#{folder}/**/*.rb")
      process(files, /module Kernel/, "module #{prefix}")
      process(files, /::#{namespace}/, "::#{prefix}::#{namespace}")
      process(files, /(?<!\w|def |:)#{namespace}\b/, "#{prefix}::#{namespace}")
      process(files, /require (["'])#{Regexp.escape require_entrypoint}/, "require \\1#{require_target}/#{require_entrypoint}")
      process(files, %r{(autoload\s+[:\w]+,\s+["'])(#{Regexp.escape require_entrypoint}[\w\/]+["'])}, "\\1#{require_target}/\\2")
    end

    def clean
      files = Dir.glob("#{vendor_lib}/*", File::FNM_DOTMATCH).reject do |f|
        basename = f.split("/").last
        allowlist.include? basename
      end
      FileUtils.rm_r files
    end

    private

    def process(files, regex, replacement = "")
      files.each do |file|
        contents = File.read(file)
        contents.gsub!(regex, replacement)
        File.open(file, "w") {|f| f << contents }
      end
    end

    def allowlist
      %(. .. lib #{license_path}).chomp " "
    end
  end
end
