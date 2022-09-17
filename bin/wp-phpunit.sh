#! /bin/bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
BIN_DIR=$SCRIPT_DIR/../../../bin
PROJECT_DIR=$SCRIPT_DIR/../../../..
CONFIG_FILEPATH=$SCRIPT_DIR/../src/wp-phpunit.xml

$BIN_DIR/wp-phpunit-install.sh
$BIN_DIR/wp-phpunit-install-wc-framework.sh

cd $PROJECT_DIR
composer dump-autoload
cd $SCRIPT_DIR

$BIN_DIR/phpunit -c $CONFIG_FILEPATH