# frozen_string_literal: true

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
      files = Dir.glob("#{vendor_lib}/*", File::FNM_DOTMATCH).reject {|f| %(. .. lib).include? f.split("/").last }
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
  end
end
