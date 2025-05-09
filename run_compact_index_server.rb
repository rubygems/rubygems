# frozen_string_literal: true

require 'bundler/setup'
require 'bundler'

require_relative "bundler/spec/support/path"
require_relative "bundler/spec/support/builders"
require_relative "bundler/spec/support/artifice/helpers/compact_index"

include Spec::Builders
include Spec::Path
include Spec::Helpers

port = ARGV[0] || 4567
repo = ARGV[1] || "repo1"

ENV["BUNDLER_SPEC_GEM_REPO"] = Spec::Path.send("gem_#{repo}").to_s

puts "CompactIndexAPI server started... http://localhost:#{port}/"

CompactIndexAPI.set :host_authorization, permitted_hosts: [".example.org", ".local", ".repo", ".repo1", ".repo2", ".repo3", ".repo4", ".rubygems.org", ".security", ".source", ".test", "127.0.0.1", "localhost"]
CompactIndexAPI.set :port, port
CompactIndexAPI.set :bind, '0.0.0.0'
CompactIndexAPI.set :server, 'webrick'
CompactIndexAPI.set :logging, true
CompactIndexAPI.set :dump_errors, true

CompactIndexAPI.run!
