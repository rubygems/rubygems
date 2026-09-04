# How to upgrade/downgrade RubyGems and Bundler:

## Upgrade Recipe

    $ gem update --system

    $ gem install bundler
    $ bundle update --bundler

## Downgrade Recipe

    $ gem update --system 4.0.20

    $ gem install bundler -v 4.0.20
    $ bundle update --bundler=4.0.20

## Install a pre-release version

    $ gem update --system --pre

    $ gem install bundler --pre
    $ bundle update --bundler=4.0.0.beta1

## Install from source

*   Download from: https://rubygems.org/pages/download
*   Unpack into a directory and `cd` there
*   Install with: `ruby setup.rb`
