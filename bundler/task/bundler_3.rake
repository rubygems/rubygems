# frozen_string_literal: true

namespace :bundler3 do
  task :install do
    ENV["BUNDLER_SPEC_SUB_VERSION"] = "3.0.0"
    Rake::Task["override_version"].invoke
    Rake::Task["install"].invoke
    sh("git", "checkout", "--", "lib/bundler/version.rb")
  end
end
