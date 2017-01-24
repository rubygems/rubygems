#!/usr/bin/env ruby

$:.unshift File.expand_path("../../lib", __FILE__)
require "rubygems"
require "optparse"

def confirm(prompt = "")
  loop do
    print(prompt)
    print(": ") unless prompt.empty?
    break if $stdin.gets.strip == "y"
  end
rescue Interrupt
  abort
end

def sh(*cmd)
  return if system(*cmd)
  raise "#{cmd} failed"
end

version = nil
prs = []

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on("--version=VERSION", "The version to release") do |v|
    version = v
  end
end.parse!

prs = ARGV.dup

version ||= begin
  version = Gem::Version.new(Gem::VERSION)
  segments = version.segments
  if segments.last.is_a?(String)
    segments << "1"
  else
    segments[-1] += 1
  end
  segments.join(".")
end

confirm "You are about to release #{version}, currently #{Gem::VERSION}"

branch = version.split(".", 3)[0, 2].join(".")
sh("git", "checkout", branch)
sh("git", "submodule", "update", "--init", "--recursive")

commits = `git log --oneline origin/master --`.split("\n").map {|l| l.split(/\s/, 2) }.reverse
commits.select! {|_sha, message| message =~ /(Auto merge of|Merge pull request) ##{Regexp.union(*prs)}/ }

unless system("git", "cherry-pick", "-x", "-m", "1", *commits.map(&:first))
  abort unless system("zsh")
end

sh(Gem.ruby, File.expand_path("../update_changelog.rb", __FILE__))

version_file = "lib/rubygems.rb"
version_contents = File.read(version_file)
unless version_contents.sub!(/^(\s*VERSION = )(["'])#{Gem::Version::VERSION_PATTERN}\2/, "\\1#{version.to_s.dump}")
  abort "failed to update #{version_file}, is it in the expected format?"
end
File.open(version_file, "w") {|f| f.write(version_contents) }

confirm "Update changelog"
sh("git", "commit", "-am", "Version #{version} with changelog")
sh("rake", "release", "VERSION=#{version}")
sh("git", "push")
sh("git", "checkout", "master")
sh("git", "pull")
unless system("git", "merge", "v#{version}", "--no-edit")
  abort unless system("zsh")
end
sh("git", "push")
