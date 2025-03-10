# frozen_string_literal: true

task :build_metadata do
  build_metadata = {
    :built_at => Spec::Path.loaded_gemspec.date.utc.strftime("%Y-%m-%d"),
    :git_commit_sha => `git rev-parse --short HEAD`.strip,
    :release => Rake::Task["release"].instance_variable_get(:@already_invoked),
  }

  Spec::Path.replace_build_metadata(build_metadata)
end

namespace :build_metadata do
  task :clean do
    build_metadata = {
      :release => false,
    }

    Spec::Path.replace_build_metadata(build_metadata)
  end
end
