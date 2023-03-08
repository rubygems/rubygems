# RubyGems [![Maintainability](https://api.codeclimate.com/v1/badges/30f913e9c2dd932132c1/maintainability)](https://codeclimate.com/github/rubygems/rubygems/maintainability)

RubyGems is a package management framework for Ruby.

A package (also known as a library) contains a set of functionality that can be invoked by a Ruby program, such as reading and parsing an XML file.
We call these packages "gems" and RubyGems is a tool to install, create, manage and load these packages in your Ruby environment.

RubyGems is also a client for [RubyGems.org](https://rubygems.org), a public repository of Gems that allows you to publish a Gem
that can be shared and used by other developers. See our guide on publishing a Gem at [guides.rubygems.org](https://guides.rubygems.org/publishing/)

## Getting Started

Installing and managing a Gem is done through the `gem` command. To install a Gem such as [Nokogiri](https://github.com/sparklemotion/nokogiri) which lets
you read and parse XML in Ruby:

    $ gem install nokogiri

RubyGems will download the Nokogiri Gem from RubyGems.org and install it into your Ruby environment.

Finally, inside your Ruby program, load the Nokogiri gem and start parsing your XML:

    require 'nokogiri'

    Nokogiri.XML('<h1>Hello World</h1>')

For more information about how to use RubyGems, see our RubyGems basics guide at [guides.rubygems.org](https://guides.rubygems.org/rubygems-basics/)

## Requirements

* RubyGems 2.6 supports Ruby 2.4 or lower.
* RubyGems 2.7 supports Ruby 2.5 or lower.
* RubyGems 3.0 supports Ruby 2.3 or later.

## Installation

RubyGems is already installed in your Ruby environment, you can check the version you have installed by running `gem --version` in your terminal emulator.

In some cases Ruby & RubyGems may be provided as OS packages. This is not a
recommended way to use Ruby & RubyGems. It's better to use a Ruby Version
Manager, such as [rbenv](https://github.com/rbenv/rbenv) or
[chruby](https://github.com/postmodern/chruby). If you still want to use the
version provided by your OS package manager, please also use your OS package
manager to upgrade rubygems, and disregard any other installation instructions
given below.

If you would like to manually install RubyGems:

* Download from https://rubygems.org/pages/download, unpack, and `cd` into RubyGems' src
* OR clone this repository and `cd` into the repository

Install RubyGems by running:

    $ ruby setup.rb

For more details and other options, see:

    $ ruby setup.rb --help

## Upgrading RubyGems

To upgrade to the latest RubyGems, run:

    $ gem update --system

See [UPGRADING](UPGRADING.md) for more details and alternative instructions.

## Documentation

RubyGems uses [rdoc](https://github.com/rdoc/rdoc) for documentation. A compiled set of the docs
can be viewed online at [rubydoc](https://www.rubydoc.info/github/rubygems/rubygems).

RubyGems also provides a comprehensive set of guides which covers numerous topics such as
creating a new gem, security practices and other resources at https://guides.rubygems.org

## Getting Help

### Filing Tickets

Got a bug and you're not sure?  You're sure you have a bug, but don't know
what to do next?  In any case, let us know about it!  The best place
for letting the RubyGems team know about bugs or problems you're having is
[on the RubyGems issues page at GitHub](https://github.com/rubygems/rubygems/issues).

### Bundler Compatibility

See https://bundler.io/compatibility for known issues.

### Supporting

RubyGems is managed by [Ruby Central](https://rubycentral.org), a non-profit organization that supports the Ruby community through projects like this one, as well as [RubyConf](https://rubyconf.org), [RailsConf](https://railsconf.org), and [RubyGems.org](https://rubygems.org). You can support Ruby Central by attending or [sponsoring](sponsors@rubycentral.org) a conference, or by [joining as a supporting member](https://rubycentral.org/#/portal/signup).

### Contributing

If you'd like to contribute to RubyGems, that's awesome, and we <3 you. Check out our [guide to contributing](CONTRIBUTING.md) for more information.

### Code of Conduct

Everyone interacting in the RubyGems project’s codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [contributor code of conduct](https://github.com/rubygems/rubygems/blob/master/CODE_OF_CONDUCT.md).
