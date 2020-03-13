#!/usr/bin/env bash

set -eo pipefail

case $1 in
  before_script)
    exec rake setup

    ;;

  rubocop)
    gem install rubocop -v "~>0.74.0"
    exec util/rubocop

    ;;

  script)
    exec rake test

    ;;

  *)
    echo "unknown args $*"
    exit 1
    ;;
esac
