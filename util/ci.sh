#!/usr/bin/env bash

set -eo pipefail

if [ -z "$TEST_TOOL" ]
then
  echo "You must specify a TEST_TOOL"
  exit 1
fi

case $1 in
  before_script)
    if [ "$TEST_TOOL" = "rubygems" ]
    then
      gemhome=$(gem env home)

      ruby -I lib bin/gem uninstall executable-hooks gem-wrappers bundler-unload -x --force -i "$gemhome@global"

      rake setup

      gem list --details
      gem env
    else
      cd bundler

      if [ -n "$BDV" ]
      then
        git reset --hard "origin/$BDV"
      fi

      rake spec:travis:deps
    fi

    ;;

  rubocop)
    gem install rubocop -v "~>0.71.0"
    util/rubocop

    ;;

  script)
    if [ "$TEST_TOOL" = "rubygems" ]
    then
      rake test
    else
      cd bundler
      rake spec:travis -t
    fi

    ;;

  *)
    echo "unknown args $*"
    exit 1
    ;;
esac
