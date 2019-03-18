#!/usr/bin/env ruby

require 'json'
require 'net/http'

def access_token_query_string
  @access_token_query_string ||= begin
    token = ENV['GITHUB_API_TOKEN']
    token ? "?access_token=#{token.strip}" : ''
  end
end

def github_api(path)
  base = 'https://api.github.com'
  url = path.start_with?(base) ? path : base + path
  url += access_token_query_string
  uri = URI.parse(url)
  return unless response = Net::HTTP.get_response(uri)
  JSON.load(response.body)
end

def wrap(text, length, indent)
  result = []
  work = text.dup

  while work.length > length
    if work =~ /^(.{0,#{length}})[ \n]/o
      result << $1
      work.slice!(0, $&.length)
    else
      result << work.slice!(0, length)
    end
  end

  result << work unless work.empty?
  result = result.reduce(String.new) do |acc, elem|
    acc << "\n" << ' ' * indent unless acc.empty?
    acc << elem
  end
  result += "\n" unless result.end_with?("\n")
  result
end

def sentence(text)
  text = text[0].upcase + text[1..-1]
  text.end_with?('.') ? text : text << '.'
end

branch = ARGV.shift || "HEAD"

history = File.read(File.expand_path('../../History.txt', __FILE__))

File.open(File.expand_path('../../ChangeLog', __FILE__), 'w') do |changelog|
  commits = `git log --oneline v#{Gem::VERSION}..#{branch}`.split("\n")
  prs = commits.reverse_each.map { |c| c =~ /(Auto merge of|Merge pull request|Merge) #(\d+)/ && $2 }.compact.uniq.sort!
  prs.each do |pr|
    next if history =~ /Pull\srequest\s##{pr}/m
    details = github_api "/repos/rubygems/rubygems/pulls/#{pr}"
    title, user = details.values_at('title', 'user')
    user = github_api(user['url'])
    name = user['name'] || user['login']
    changelog << wrap(
      ['*', sentence(title), sentence("Pull request ##{pr} by #{name}")].join(' '),
      74, 2
    )
  end
end
