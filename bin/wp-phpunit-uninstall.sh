#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR")"; pwd -P)/$(basename "$SCRIPT_DIR")"

if [ -f $SCRIPT_DIR/.env ]
then
	export $(cat $SCRIPT_DIR/.env | xargs)
fi

TMPDIR=${TMPDIR-/tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")
WORDPRESS_TESTS_DIR=${WORDPRESS_TESTS_DIR-$TMPDIR/dmitryrechkin/wp/tests-lib}
WORDPRESS_CORE_DIR=${WORDPRESS_CORE_DIR-$TMPDIR/dmitryrechkin/wp/www}
WORDPRESS_DB_DIR=${WORDPRESS_DB_DIR-$TMPDIR/dmitryrechkin/wp/db}
WORDPRESS_LOGS_DIR=${WORDPRESS_LOGS_DIR-$TMPDIR/dmitryrechkin/wp/logs}

echo "Uninstalling..."

echo "Stopping Docker containers..."
docker stop $WORDPRESS_DB_HOST
docker stop $WORDPRESS_HOST

echo "Removing folders..."
rm -rf $WORDPRESS_TESTS_DIR
rm -rf $WORDPRESS_CORE_DIR
rm -rf $WORDPRESS_DB_DIR
rm -rf $WORDPRESS_LOGS_DIR
rm -rf $SCRIPT_DIR/../framework/helpers
rm -rf $SCRIPT_DIR/../framework/traits
rm -rf $SCRIPT_DIR/../framework/vendor
rm -rf $SCRIPT_DIR/../framework/*.php

echo "Done"