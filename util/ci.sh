#!/usr/bin/env bash

set -xeo pipefail

if [ -z "$TEST_TOOL" ]
then
  echo "You must specify a TEST_TOOL"
  exit 1
fi

case $1 in
  before_script)
    if [ -d "$HOME/.rvm" ]
    then
      gemhome=$(gem env home)
      ruby -I lib bin/gem uninstall executable-hooks gem-wrappers bundler-unload -x --force -i "$gemhome@global"
    fi

    ruby -I lib bin/gem env

    [ -d "$HOME/.gem/ruby/2.7.0" ] && echo "Exists"

    mkdir -p "$HOME/.gem/ruby/2.7.0"

    ruby -I lib bin/gem install rake -v "~>12.0"

    if [ "$TEST_TOOL" = "rubygems" ]
    then
      exec rake setup
    else
      cd bundler

      export RGV=..

      if [ -n "$BDV" ]
      then
        git reset --hard "origin/$BDV"
      fi

      exec bin/rake spec:deps
    fi

    ;;

  rubocop)
    gem install rubocop -v "~>0.74.0"
    exec util/rubocop

    ;;

  script)
    if [ "$TEST_TOOL" = "rubygems" ]
    then
      exec rake test
    else
      cd bundler

      export RGV=..

      exec bin/rspec ./spec/other/cli_dispatch_spec.rb
    fi

    ;;

  *)
    echo "unknown args $*"
    exit 1
    ;;
esac
