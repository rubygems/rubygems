#!/usr/bin/env ruby
require 'optparse'

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

File.open(File.join(directory, "yaml"), "w") do |file|
  i = nil
  file.puts "--- !ruby/object:Gem::Cache"
  file.puts "gems:" 

  Dir.glob(File.join(directory, "gems", "*.gem")).each do |filename|
    data = File.read(filename)
    i = data.index(/\!ruby\/object\:Gem\:\:Specification/)
    data = data[i...data.index(/---/, i+3)]
    gem = File.basename(filename)[0..-5]
    file.puts "  #{gem}: #{data.gsub(/\n/, "\n    ")}"
  end
end

