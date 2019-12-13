#!/usr/bin/env bash

set -eo pipefail

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

      gem install rake -v "~>12.0"
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

      exec bin/rake spec -t
    fi

    ;;

  *)
    echo "unknown args $*"
    exit 1
    ;;
esac
