#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR")"; pwd -P)/$(basename "$SCRIPT_DIR")"

if [ -f $SCRIPT_DIR/.env ]
then
	export $(cat $SCRIPT_DIR/.env | xargs)
fi

echo "Stopping Docker containers..."
docker stop $WORDPRESS_DB_HOST
docker stop $WORDPRESS_HOST

echo "Done"