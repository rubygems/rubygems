require 'yaml'
require 'ostruct'

# Taken from 'extensions' RubyForge project.
module Enumerable
  def partition_by
    result = {}
    self.each do |e|
      value = yield e
      (result[value] ||= []) << e
    end
    result
  end
end

data = YAML.load(File.read('specdoc.yaml'))

SECTIONS = data['SECTIONS']
ATTRIBUTES = data['ATTRIBUTES'].reject { |a| a['name'] == '...' }

def _link(attribute, text=nil)
  link = "http://rubygems.rubyforge.org/wiki/wiki.pl?GemspecsInDetail##{attribute}"
  "[#{link} #{text || attribute}]"
end

def themed_toc
  SECTIONS.each do |s|
    puts "\n'''#{s['name']}'''"
    puts s['attributes'].map { |a|
      ": #{_link(a, '#')} #{a}"
    }
  end
end

def alpha_toc
  require 'rubygems'
  require_gem 'dev-utils'
  require 'dev-utils/debug'
  attributes = SECTIONS.map { |s| s['attributes'] }.flatten   # ['author', 'autorequire', ...]
  attr_map = attributes.partition_by { |a| a[0,1] }           # { 'a' => ['author', ...], 'b' => ... }
  attributes = attr_map.map { |letter, attrs|
    [letter.upcase, attrs.sort]
  }.sort_by { |l, _| l }                                      # [ ['A', ['author', ...], ...]
  attributes = attributes.map { |letter, attrs|
    "'''#{letter}''' " << attrs.map { |a| _link(a) }.join(' | ')
  }
  puts attributes.join(' ')
#  puts attributes.map { |str|
#    if str =~ /^[A-Z]$/
#      "'''#{str}'''"
#    else
#      _link(str)
#    end
#  }.join(' | ')
end

def _metadata(attribute)
  result = "\n''" << \
    case attribute.mandatory
    when nil, false then 'Optional'
    when '?' then 'Required???'
    else 'Required'
    end
  default = attribute.default
  unless default.nil?
    default_str =
      case default
      when 'nil' then 'nil'
      when '...' then '(see below)'
      else default.inspect
      end
    result << "; default = #{default_str}"
  end
  result << "''\n"
end

def _resolve_links(text)
  text.gsub(/L\((\w+)\)/) { _link($1) }
end

def attribute_survey
  ATTRIBUTES.sort_by { |a| a['name'] }.each do |a|
    a = OpenStruct.new(a)
    puts "\n\n== [\##{a.name}] #{a.name} =="
    puts _metadata(a)
    puts "\n=== Description ===\n\n"
    puts _resolve_links(a.description)
    puts "\n=== Usage ===\n\n"
    puts "<pre>"
    puts a.usage.gsub(/^/, '  ')
    puts "</pre>"
    if a.notes
      puts "\n=== Notes ===\n\n"
      puts _resolve_links(a.notes)
    end
    puts "\n''#{_link('toc', '^ Table of Contents')}''"
  end
end

IO.foreach('specdoc.data') do |line|
  case line
  when /^!(\S+)\s*$/
      # A line beginning with a ! is a command.  We call the method of that name.
    self.send($1)
  else
    puts line.chomp
  end
end
