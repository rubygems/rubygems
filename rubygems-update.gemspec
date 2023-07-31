# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "rubygems-update"
  s.version = "3.4.18"
  s.authors = ["Jim Weirich", "Chad Fowler", "Eric Hodel", "Luis Lavena", "Aaron Patterson", "Samuel Giddins", "André Arko", "Evan Phoenix", "Hiroshi SHIBATA"]
  s.email = ["", "", "drbrain@segment7.net", "luislavena@gmail.com", "aaron@tenderlovemaking.com", "segiddins@segiddins.me", "andre@arko.net", "evan@phx.io", "hsbt@ruby-lang.org"]

  s.summary = "RubyGems is a package management framework for Ruby. This gem is downloaded and installed by `gem update --system`, so that the `gem` CLI can update itself."
  s.description = "A package (also known as a library) contains a set of functionality
  that can be invoked by a Ruby program, such as reading and parsing an XML file. We call
  these packages 'gems' and RubyGems is a tool to install, create, manage and load these
  packages in your Ruby environment. RubyGems is also a client for RubyGems.org, a public
  repository of Gems that allows you to publish a Gem that can be shared and used by other
  developers. See our guide on publishing a Gem at guides.rubygems.org"
  s.homepage = "https://guides.rubygems.org"
  s.metadata = { "source_code_uri" => "https://github.com/rubygems/rubygems" }
  s.licenses = ["Ruby", "MIT"]

  s.files = File.read("Manifest.txt").split
  s.bindir = "exe"
  s.executables = ["update_rubygems"]
  s.require_paths = ["hide_lib_for_update"]
  s.rdoc_options = ["--main", "README.md", "--title=RubyGems Update Documentation"]
  s.extra_rdoc_files = [
    "CHANGELOG.md", "LICENSE.txt", "MAINTAINERS.txt",
    "MIT.txt", "Manifest.txt", "README.md",
    "UPGRADING.md", "POLICIES.md", "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md", "bundler/CHANGELOG.md",
    "bundler/LICENSE.md", "bundler/README.md",
    "hide_lib_for_update/note.txt", *Dir["bundler/man/*.1"]
  ]

  s.required_ruby_version = Gem::Requirement.new(">= 2.6.0")
  s.required_rubygems_version = Gem::Requirement.new(">= 0")

  s.specification_version = 4
end
