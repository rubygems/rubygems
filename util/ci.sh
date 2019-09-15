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
      exec rake setup
    else
      cd bundler

      if [ -n "$BDV" ]
      then
        git reset --hard "origin/$BDV"
      fi

      exec rake spec:travis:deps
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
      exec rake spec:travis -t
    fi

    ;;

  *)
    echo "unknown args $*"
    exit 1
    ;;
esac
