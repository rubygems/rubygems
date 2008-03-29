#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'yaml'
require 'ostruct'
require 'rubygems'

SEPSTRING = ' .. '

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

  # Returns a link to the given anchor on the page.
def _link(attribute, text=nil)
  link = "##{attribute}"
  %{<a href="#{link}">#{text || attribute}</a>}
end

def _themed_toc_more_vspace
  SECTIONS.each do |s|
    puts "\n* *#{s['name']}*"
    puts s['attributes'].collect { |a|
      ": #{_link(a, '#')} #{a}"
    }
  end
end

def _themed_toc_less_vspace
  SECTIONS.each do |s|
    puts "\n* *#{s['name']}:* "
    puts s['attributes'].collect { |a| _link(a) }.join(SEPSTRING)
  end
end

def timestamp
  puts "p(((. <em>Last generated: #{Time.now.strftime '%Y-%m-%d %H:%M:%S %Z (%A)'}</em>"
end

  # Prints a thematic table of contents, drawing from the structure in the YAML file.
def themed_toc
  _themed_toc_less_vspace
end

  # Prints an alphabetical table of contents in a fairly compact yet readable way, with all
  # Wiki formatting included.
def alpha_toc
  attributes = SECTIONS.collect { |s| s['attributes'] }.flatten
    # -> ['author', 'autorequire', ...]
  attr_map = attributes.partition_by { |a| a[0,1] }
    # -> { 'a' => ['author', ...], 'b' => ... }
  attributes = attr_map.collect { |letter, attrs|
    [letter.upcase, attrs.sort]
  }.sort_by { |l, _| l }
    # -> [ ['A', ['author', ...], ...]
  attributes = attributes.collect { |letter, attrs|
    "* *#{letter}* " << attrs.collect { |a| _link(a) }.join(SEPSTRING)
  } # -> [ 'A author | autorequire', 'B bindir', ...]
  puts attributes.join("\n")
end

  # Print the "important" table of contents, which consists of the attributes given as
  # arguments.
def important_toc(*attributes)
  puts attributes.collect { |a| _link(a) }.join(SEPSTRING)
end

  # Returns text like "Optional; default = 'bin'", with Wiki formatting.
def _metadata(attribute)
  type = attribute.klass || "Unknown"
  required = 
    case attribute.mandatory
    when nil, false
      '<em>Optional</em>'
    else
      '<em>Required</em>'
    end
  default_str =
    case attribute.default
    when nil then ''
    when 'nil' then 'nil'
    when '...' then '(see below)'
    else attribute.default.inspect
    end
  default_str = ";   default = #{default_str}" unless default_str.empty?
  result = sprintf "<em>Type: %s;   %s%s</em>", type, required, default_str
#  result.gsub(/ /, '&nbsp;')
end

  # Turns 'L(section)' into a link to that section.
def _resolve_links(text)
  text.gsub(/L\((\w+)\)/) { _link($1) }
end

  # For each attribute ('extra_rdoc_files', 'bindir', etc.), prints a section containing:
  # * a heading
  # * a line describing the attribute's type, mandatoriness, and default
  # * the description, usage, and notes for that attribute
  # * a link to the table of contents
def attribute_survey
  heading    = proc { |str| %{\n\nh3. <a name="#{str}">#{str}</a>\n\n} }
  subheading = proc { |str| "\n\nh4. #{str}\n\n" }
  pre        = proc { |str| "<pre>\n#{str}\n</pre>\n" }
  para       = proc { |str| str.gsub(/\n/, "\n\n") }
  toclink    = "\n<em>Goto #{_link('toc', 'Table of Contents')}</em>"
  ATTRIBUTES.sort_by { |a| a['name'] }.each do |a|
    a = OpenStruct.new(a)
    puts "\n----\n"
    puts heading[a.name]
    puts _metadata(a)
    puts subheading['Description']
    puts _resolve_links(a.description)
    puts subheading['Usage']
    puts pre[a.usage.strip.gsub(/^/, '  ')]
    if a.notes
      puts subheading['Notes']
      puts _resolve_links(para[a.notes.strip])
    end
    puts toclink
  end
end

  # Checks to see that all the attributes are documented.  Warn on STDERR of any
  # discrepencies.
def _check_attribute_completeness
  documented_attributes = ATTRIBUTES.collect { |a| a['name'].to_s }
    # ^ The attributes documented in specdoc.yaml.
  coded_attributes      = Gem::Specification.attribute_names.collect { |a| a.to_s }
    # ^ The attributes defined in specification.rb.
  missing = coded_attributes - documented_attributes
  unless missing.empty?
    STDERR.puts "Defined attributes that are not documented:"
    STDERR.puts '  ' + missing.join(', ')
  end
  missing = documented_attributes - coded_attributes
  unless missing.empty?
    STDERR.puts "Documented attributes that are not defined:"
    STDERR.puts '  ' + missing.join(', ')
  end
end

# # #    M A I N    # # #

data = YAML.load(File.read('specdoc.yaml'))
SECTIONS = data['SECTIONS']
ATTRIBUTES = data['ATTRIBUTES'].reject { |a| a['name'] == '...' }

_check_attribute_completeness

IO.foreach('specdoc.data') do |line|
  case line
  when /^!(\S+)/
      # A line beginning with a ! is a command.  We call the method of that name.
    cmd, *args = line[1..-1].split
    self.send(cmd, *args)
  else
    puts line.chomp
  end
end

