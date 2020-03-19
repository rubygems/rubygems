# Rubygems + Bundler

> Rubygems and Bundler [got merged](https://github.com/rubygems/rubygems/pull/3166) into a single repository

# Rubygems

RubyGems is a package management framework for Ruby.

A package (also known as a library) contains a set of functionality that can be invoked by a Ruby program, such as reading and parsing an XML file.
We call these packages "gems" and RubyGems is a tool to install, create, manage and load these packages in your Ruby environment.

RubyGems is also a client for [RubyGems.org](https://rubygems.org), a public repository of Gems that allows you to publish a Gem
that can be shared and used by other developers. See our guide on publishing a Gem at [guides.rubygems.org](https://guides.rubygems.org/publishing/)

[See documentation](https://github.com/rubygems/rubygems/blob/master/RUBYGEMS_README.md)

# Bundler

Bundler makes sure Ruby applications run the same code on every machine.

It does this by managing the gems that the application depends on. Given a list of gems, it can automatically download and install those gems, as well as any other gems needed by the gems that are listed. Before installing gems, it checks the versions of every gem to make sure that they are compatible, and can all be loaded at the same time. After the gems have been installed, Bundler can help you update some or all of them when new versions become available. Finally, it records the exact versions that have been installed, so that others can install the exact same gems.

[See documentation](https://github.com/rubygems/rubygems/blob/master/bundler/README.md)

### Supporting

<a href="https://rubytogether.org/"><img src="https://rubytogether.org/images/rubies.svg" width=200></a><br/>
<a href="https://rubytogether.org/">Ruby Together</a> pays some RubyGems maintainers for their ongoing work. As a grassroots initiative committed to supporting the critical Ruby infrastructure you rely on, Ruby Together is funded entirely by the Ruby community. Contribute today <a href="https://rubytogether.org/developers">as an individual</a> or even better, <a href="https://rubytogether.org/companies">as a company</a>, and ensure that RubyGems, Bundler, and other shared tooling is around for years to come.

### Contributing

If you'd like to contribute to RubyGems or Bundler, that's awesome, and we <3 you. Check out the [Rubygems contributing guide](CONTRIBUTING.md) or the [Bundler contributing guide](https://github.com/rubygems/rubygems/tree/master/bundler/doc/contributing) for more information.

While some RubyGems and Bundler contributors are compensated by Ruby Together, the project maintainers make decisions independent of Ruby Together. As a project, we welcome contributions regardless of the author’s affiliation with Ruby Together.

### Code of Conduct

Everyone interacting in the RubyGems and Bundler project’s codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [contributor code of conduct](https://github.com/rubygems/rubygems/blob/master/CODE_OF_CONDUCT.md).
