#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'mechanize'
require 'fileutils'

DOC = {}
UPDATED = {}
MISSING = []

$page_count = 0

def save_page(page)
  $page_count += 1
  page_name = "logs/page_%03d.html" % $page_count
  open(page_name, "w") do |f| f.puts page.body end
end

def read_document
  open("scripts/gemdoc.hieraki") do |f|
    name = nil
    f.each do |line|
      if line =~ /^==/
        line =~ /gem\s+(\S+)/ or fail "Illformatted Document Line [#{line.chomp}]"
        name = $1
        DOC[name] = ''
      else
        next if name.nil?
        DOC[name] << line
      end
    end
  end
end

def get_credentials
  unless File.exist?(".hieraki_author.rb")
    print "Hieraki Author Name: "
    author = gets.chomp
    print "Hieraki Password: "
    password = gets.chomp
    open(".hieraki_author.rb", "w") do |f|
      f.puts "module Hieraki"
      f.puts "  Author = '#{author}'"
      f.puts "  Password = '#{password}'"
      f.puts "end"
    end
  end
  
  load "./.hieraki_author.rb"
end

def create_agent
  FileUtils.mkdir "logs" unless File.exist?("logs")
  logfile = open("logs/update_hieraki.log", "w") 
  $agent = WWW::Mechanize.new { |a| a.log = Logger.new(logfile) }
end

def login_to_hieraki
  puts "*** Getting Start Page"
  start_page = $agent.get("http://docs.rubygems.org")
  save_page(start_page)
  
  puts "*** Going to Login Page"
  login_link = start_page.links.find { |l| l.node.text =~ /login/i }
  login_page = $agent.click(login_link)
  save_page(login_page)
  
  puts "*** Attempting to Log In"
  login_form = login_page.forms.first
  login_form.fields.find { |f| f.name == 'login' }.value = Hieraki::Author
  login_form.fields.find { |f| f.name == 'password' }.value = Hieraki::Password
  author_page = $agent.submit(login_form)
  fail "Unsuccessful Login -- check .hieraki_author.rb file" if author_page.body =~ /unsuccessful/
  save_page(author_page)
  author_page
end


def goto_command_reference_page(page)
  puts "*** Going to Command Reference Book"
  link = page.links.find { |l| l.node.text =~ /command reference/i }
  ref_page = $agent.click(link)
  save_page(ref_page)
  
  puts "*** Going to Command Reference Chapter"
  link = ref_page.links.find { |l| l.node.text =~ /command reference/i && l.href =~ /chapter/ }
  cmdref_page = $agent.click(link)
  save_page(cmdref_page)
  cmdref_page
end

def update_command_docs(cmdref_page)
  cmdref_page.links.select { |l| l.node.text == "edit" }.each do |l|
    edit_page = $agent.click(l)
    save_page(edit_page)
    edit_form = edit_page.forms.first
    title = edit_form.fields.find { |f| f.name = 'page_title'}.value
    if title =~ /gem\s([a-z]+)/
      name = $1
      if DOC[name]
        body_field = edit_form.fields.find { |f| f.name == 'page[body]'}
        body_field.value = DOC[name]
        puts "*** Updating gem #{name} page"
        $agent.submit(edit_form)
        UPDATED[name] = true
      else
        MISSING << name
      end
    end
  end
end


def check_missing
  (DOC.keys - UPDATED.keys).sort.each do |name|
    puts "No page found for 'gem #{name}'"
  end
  MISSING.each do |name|
    puts "No data found for 'gem #{name}' page"
  end
end

def upload_gemdoc_main(args)
  create_agent
  get_credentials
  read_document
  page = login_to_hieraki
  cmdref_page = goto_command_reference_page(page)
  update_command_docs(cmdref_page)
  check_missing
end

if __FILE__ == $0 then
  upload_gemdoc_main(ARGV)
end
