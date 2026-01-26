# How to upgrade/downgrade Rubygems and Bundler:

## Upgrade Recipe

    $ gem update --system

    $ gem install bundler
    $ bundle update --bundler

## Downgrade Recipe

    $ gem update --system 3.7.2

    $ gem install bundler -v 2.7.2
    $ bundle update --bundler=2.7.2

## Install a pre-release version

    $ gem update --system --pre

    $ gem install bundler --pre
    $ bundle update --bundler=4.0.0.beta1

## Install from source

*   Download from: https://rubygems.org/pages/download
*   Unpack into a directory and `cd` there
*   Install with: `ruby setup.rb`
