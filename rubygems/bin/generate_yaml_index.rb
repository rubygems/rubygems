#!/usr/bin/env ruby
$:.unshift '~/rubygems'

require 'optparse'
require 'rubygems'
require 'zlib'

Gem.manage_gems

options = {}
ARGV.options do |opts|
  opts.on_tail("--help", "show this message") {puts opts; exit}
  opts.on('-d', '--dir=DIRNAME', "base directory with dir/gems", String) {|options[:directory]|}
  opts.parse!
end

directory = options[:directory]
unless directory
  puts "Error, must specify directory name. Use --help"
  exit
else
  unless File.exist?(directory) && File.directory?(directory)
    puts "Error, unknown directory name #{directory}."
    exit
  end
end

class Indexer

  def initialize(directory)
    @directory = directory
  end

  def gem_file_list
    Dir.glob(File.join(@directory, "gems", "*.gem"))
  end

  def build_index
    File.open(File.join(@directory, "yaml"), "w") do |file|
      file.puts "--- !ruby/object:Gem::Cache"
      file.puts "gems:"
      gem_file_list.each do |gemfile|
        spec = Gem::Format.from_file_by_path(gemfile).spec
        file.puts "  #{spec.full_name}: #{spec.to_yaml.gsub(/\n/, "\n    ")[4..-1]}"
      end
    end
    build_compressed_index
  end
  
  def build_compressed_index
    File.open(File.join(@directory, "yaml.Z"), "w") do |file|
      file.write(Zlib::Deflate.deflate(File.read(File.join(@directory, "yaml"))))
    end
  end
end


Indexer.new(directory).build_index
