require 'yaml'
require 'ostruct'

data = YAML.load(File.read('specdoc.yaml'))

SECTIONS = data['SECTIONS']
ATTRIBUTES = data['ATTRIBUTES']

def _link(attribute)
  link = "http://rubygems.rubyforge.org/wiki/wiki.pl?GemspecsInDetail##{attribute}"
  "[#{link} #]"
end

def themed_toc
  SECTIONS.each do |s|
    puts "\n==== #{s['name']} ====\n\n"
    puts s['attributes'].map { |a|
      "* #{a} #{_link(a)}"
    }
  end
end

def alpha_toc
  attributes = SECTIONS.map { |s| s['attributes'] }.flatten
  attributes.each do |a|
    puts "* #{a} #{_link(a)}"
  end
end

def attribute_survey
  ATTRIBUTES.each do |a|
    a = OpenStruct.new(a)
    puts "\n\n== [\##{a.name}] #{a.name} =="
    puts "\n=== Description ===\n\n"
    puts a.description
    puts "\n=== Usage ===\n\n"
    puts "<pre>"
    puts a.usage
    puts "</pre>"
    puts "\n=== Notes ===\n\n"
    puts a.notes
  end
end

IO.foreach('specdoc.data') do |line|
  case line
  when /^!(\S+)\s*$/
    self.send($1)
  else
    puts line.chomp
  end
end
