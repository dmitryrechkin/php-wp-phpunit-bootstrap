#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR")"; pwd -P)/$(basename "$SCRIPT_DIR")"

if [ -f $SCRIPT_DIR/.env ]
then
	export $(cat $SCRIPT_DIR/.env | xargs)
fi

TMPDIR=${TMPDIR-/tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")

echo "Installing WooCommerce tests framework..."

FRAMEWORK_TARGET_DIR="$SCRIPT_DIR/.."

if [ -d "$FRAMEWORK_TARGET_DIR/framework/helpers" ]; then
	echo "framework already exists, so skip it"
	exit
fi

echo "Checking out woocommerce repo..."
git clone https://github.com/woocommerce/woocommerce.git "$TMPDIR/woocommerce"
cd "$TMPDIR/woocommerce"
git switch master

echo "Make $FRAMEWORK_TARGET_DIR directory..."
mkdir -p $FRAMEWORK_TARGET_DIR

echo "Copying framework..."
cp -r tests/legacy/framework "$FRAMEWORK_TARGET_DIR/"

cd $SCRIPT_DIR

echo "Removing woocommerce folder..."
rm -rf "$TMPDIR/woocommerce"