# RubyGems [![Travis Build Status](https://secure.travis-ci.org/rubygems/rubygems.svg?branch=master)](http://travis-ci.org/rubygems/rubygems) [![Appveyor Build Status](https://ci.appveyor.com/api/projects/status/github/rubygems/rubygems?branch=master&svg=true)](https://ci.appveyor.com/project/rubygems/rubygems?branch=master)

RubyGems is a package management framework for Ruby.

This gem is an update for the RubyGems software. You must have an
installation of RubyGems before this update can be applied.

See Gem for information on RubyGems (or `ri Gem`)

To upgrade to the latest RubyGems, run:

```
  $ gem update --system  # you might need to be an administrator or root
```

See [UPGRADING](UPGRADING.rdoc) for more details and alternative instructions.

-----

If you don't have RubyGems installed, you can still do it manually:

* Download from https://rubygems.org/pages/download, unpack, and `cd` there
* OR clone this repository and `cd` there (make sure to run `git submodule update --init`)
* Install with `ruby setup.rb` (you may need admin/root privilege)

For more details and other options, see:

```
  ruby setup.rb --help
```

## Documentation

RubyGems uses [rdoc](https://github.com/rdoc/rdoc) for documentation. A compiled set of the docs
can be viewed online at http://www.rubydoc.info/github/rubygems/rubygems

RubyGems also provides a comprehensive set of guides which covers numerous topics such as
creating a new gem, security practices and other resources at http://guides.rubygems.org

## GETTING HELP

### Support Requests

Are you unsure of how to use RubyGems?  Do you think you've found a bug and
you're not sure?  If that is the case, the best place for you is to file a
support request at [help.rubygems.org](http://help.rubygems.org).

### Filing Tickets

Got a bug and you're not sure?  You're sure you have a bug, but don't know
what to do next?  In any case, let us know about it!  The best place
for letting the RubyGems team know about bugs or problems you're having is
[on the RubyGems issues page at GitHub](http://github.com/rubygems/rubygems/issues).

### Bundler Compatibility

See http://bundler.io/compatibility for known issues.

### Supporting

<a href="https://rubytogether.org/"><img src="https://rubytogether.org/images/rubies.svg" width=200></a><br/>
<a href="https://rubytogether.org/">Ruby Together</a> pays some RubyGems maintainers for their ongoing work. As a grassroots initiative committed to supporting the critical Ruby infrastructure you rely on, Ruby Together is funded entirely by the Ruby community. Contribute today <a href="https://rubytogether.org/developers">as an individual</a> or even better, <a href="https://rubytogether.org/companies">as a company</a>, and ensure that RubyGems, Bundler, and other shared tooling is around for years to come.

### Contributing

If you'd like to contribute to RubyGems, that's awesome, and we <3 you. Check out our [guide to contributing](https://github.com/rubygems/rubygems/blob/master/CONTRIBUTING.rdoc#how-to-contribute) for more information.

While some RubyGems contributors are compensated by Ruby Together, the project maintainers make decisions independent of Ruby Together. As a project, we welcome contributions regardless of the author’s affiliation with Ruby Together.

### Code of Conduct

Everyone interacting in the RubyGems project’s codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [contributor code of conduct](https://github.com/rubygems/rubygems/blob/master/CODE_OF_CONDUCT.md).
