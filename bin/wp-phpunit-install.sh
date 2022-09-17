#!/usr/bin/env bash
# See https://raw.githubusercontent.com/wp-cli/scaffold-command/master/templates/install-wp-tests.sh

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR")"; pwd -P)/$(basename "$SCRIPT_DIR")"

if [ -f $SCRIPT_DIR/.env ]; then
	export $(cat $SCRIPT_DIR/.env | xargs)
fi

TMPDIR=${TMPDIR-/tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")
WORDPRESS_TESTS_DIR=${WORDPRESS_TESTS_DIR-$TMPDIR/dmitryrechkin/wp/tests-lib}
WORDPRESS_CORE_DIR=${WORDPRESS_CORE_DIR-$TMPDIR/dmitryrechkin/wp/www}
WORDPRESS_DB_DIR=${WORDPRESS_DB_DIR-$TMPDIR/dmitryrechkin/wp/db}
WORDPRESS_LOGS_DIR=${WORDPRESS_LOGS_DIR-$TMPDIR/dmitryrechkin/wp/logs}
WORDPRESS_VERSION=${WORDPRESS_VERSION-nightly}
DOCKER_EXEC_DB="docker exec -it $WORDPRESS_DB_HOST"
DOCKER_EXEC_WP="docker exec -it $WORDPRESS_HOST"

download() {
	echo "Downloading $1 to $2 ..."

	if [ `which curl` ]; then
		curl -s "$1" > "$2";
	elif [ `which wget` ]; then
		wget -nv -O "$2" "$1"
	fi
}

if [[ $WORDPRESS_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
	WP_TESTS_TAG="branches/$WORDPRESS_VERSION"
elif [[ $WORDPRESS_VERSION =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
	if [[ $WORDPRESS_VERSION =~ [0-9]+\.[0-9]+\.[0] ]]; then
		# version x.x.0 means the first release of the major version, so strip off the .0 and download version x.x
		WP_TESTS_TAG="tags/${WORDPRESS_VERSION%??}"
	else
		WP_TESTS_TAG="tags/$WORDPRESS_VERSION"
	fi
elif [[ $WORDPRESS_VERSION == 'nightly' || $WORDPRESS_VERSION == 'trunk' ]]; then
	WP_TESTS_TAG="trunk"
else
	# http serves a single offer, whereas https serves multiple. we only want one
	download http://api.wordpress.org/core/version-check/1.7/ $TMPDIR/wp-latest.json
	grep '[0-9]+\.[0-9]+(\.[0-9]+)?' $TMPDIR/wp-latest.json
	LATEST_VERSION=$(grep -o '"version":"[^"]*' $TMPDIR/wp-latest.json | sed 's/"version":"//')
	if [[ -z "$LATEST_VERSION" ]]; then
		echo "Latest WordPress version could not be found"
		exit 1
	fi
	WP_TESTS_TAG="tags/$LATEST_VERSION"
fi

#set -ex

check_installation() {
	if [ -d $WORDPRESS_CORE_DIR ]; then
		echo "$WORDPRESS_CORE_DIR already exists, so we won't continue. You can run vendor/bin/wp-phpunit-uninstall.sh first if you want to reinstall it."

		exit 0
	fi
}

install_wp() {
	echo "Installing WordPress to $WORDPRESS_CORE_DIR ..."

	if [ -d $WORDPRESS_CORE_DIR ]; then
		echo "$WORDPRESS_CORE_DIR already exists, so skip it"
		return 0
	fi

	mkdir -p $WORDPRESS_CORE_DIR

	if [[ $WORDPRESS_VERSION == 'nightly' || $WORDPRESS_VERSION == 'trunk' ]]; then
		mkdir -p $TMPDIR/wordpress-nightly
		download https://wordpress.org/nightly-builds/wordpress-latest.zip  $TMPDIR/wordpress-nightly/wordpress-nightly.zip
		unzip -q $TMPDIR/wordpress-nightly/wordpress-nightly.zip -d $TMPDIR/wordpress-nightly/
		mv $TMPDIR/wordpress-nightly/wordpress/* $WORDPRESS_CORE_DIR
	else
		if [ $WORDPRESS_VERSION == 'latest' ]; then
			local ARCHIVE_NAME='latest'
		elif [[ $WORDPRESS_VERSION =~ [0-9]+\.[0-9]+ ]]; then
			# https serves multiple offers, whereas http serves single.
			download https://api.wordpress.org/core/version-check/1.7/ $TMPDIR/wp-latest.json
			if [[ $WORDPRESS_VERSION =~ [0-9]+\.[0-9]+\.[0] ]]; then
				# version x.x.0 means the first release of the major version, so strip off the .0 and download version x.x
				LATEST_VERSION=${WORDPRESS_VERSION%??}
			else
				# otherwise, scan the releases and get the most up to date minor version of the major release
				local VERSION_ESCAPED=`echo $WORDPRESS_VERSION | sed 's/\./\\\\./g'`
				LATEST_VERSION=$(grep -o '"version":"'$VERSION_ESCAPED'[^"]*' $TMPDIR/wp-latest.json | sed 's/"version":"//' | head -1)
			fi
			if [[ -z "$LATEST_VERSION" ]]; then
				local ARCHIVE_NAME="wordpress-$WORDPRESS_VERSION"
			else
				local ARCHIVE_NAME="wordpress-$LATEST_VERSION"
			fi
		else
			local ARCHIVE_NAME="wordpress-$WORDPRESS_VERSION"
		fi
		download https://wordpress.org/${ARCHIVE_NAME}.tar.gz  $TMPDIR/wordpress.tar.gz
		tar --strip-components=1 -zxmf $TMPDIR/wordpress.tar.gz -C $WORDPRESS_CORE_DIR
	fi

	download https://raw.github.com/markoheijnen/wp-mysqli/master/db.php $WORDPRESS_CORE_DIR/wp-content/db.php

	download https://raw.githubusercontent.com/docker-library/wordpress/master/wp-config-docker.php $WORDPRESS_CORE_DIR/wp-config.php
}

install_wp_cli() {
	echo "Installing WP CLI ..."

	#mkdir -p $WORDPRESS_CORE_DIR

	download https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar $WORDPRESS_CORE_DIR/wp-cli.phar
}

install_test_suite() {
	echo "Installing Test Suite to $WORDPRESS_TESTS_DIR ..."

	# portable in-place argument for both GNU sed and Mac OSX sed
	if [[ $(uname -s) == 'Darwin' ]]; then
		local ioption='-i .bak'
	else
		local ioption='-i'
	fi

	# set up testing suite if it doesn't yet exist
	if [ ! -d $WORDPRESS_TESTS_DIR ]; then
		# set up testing suite
		mkdir -p $WORDPRESS_TESTS_DIR
		svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/includes/ $WORDPRESS_TESTS_DIR/includes
		svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/data/ $WORDPRESS_TESTS_DIR/data
	fi

	if [ ! -f wp-tests-config.php ]; then
		download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		# remove all forward slashes in the end
		WORDPRESS_CORE_DIR=$(echo $WORDPRESS_CORE_DIR | sed "s:/\+$::")
		sed $ioption -E "s:(__DIR__ . '/src/'|dirname\( __FILE__ \) . '/src/'):'$WORDPRESS_CORE_DIR/':" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/youremptytestdbnamehere/$WORDPRESS_DB_NAME/" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourusernamehere/$WORDPRESS_DB_USER/" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourpasswordhere/$WORDPRESS_DB_PASSWORD/" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s|localhost|127.0.0.1:${WORDPRESS_DB_PORT-3306}|" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s|example.org|localhost|" "$WORDPRESS_TESTS_DIR"/wp-tests-config.php
	fi
}

create_db() {

	if [ "${SKIP_DB_CREATE}" = "true" ]; then
		return 0
	fi

	echo "Creating database..."

	# If we're trying to connect to a socket we want to handle it differently.
	if [[ "$WORDPRESS_DB_HOST" == *.sock ]]; then
		# create database using the socket
		$DOCKER_EXEC_DB mysqladmin create $WORDPRESS_DB_NAME --socket="$WORDPRESS_DB_HOST"
	else
		# Decide whether or not there is a port.
		#local PARTS=(${WORDPRESS_DB_HOST//\:/ })
		#if [[ ${PARTS[1]} =~ ^[0-9]+$ ]]; then
		#	EXTRA=" --host=${PARTS[0]} --port=${PARTS[1]} --protocol=tcp"
		#else
		#	EXTRA=" --host=$WORDPRESS_DB_HOST --protocol=tcp"
		#fi

		# create database
		$DOCKER_EXEC_DB mysqladmin create $WORDPRESS_DB_NAME --user="$WORDPRESS_DB_USER" --password="$WORDPRESS_DB_PASSWORD"$EXTRA
	fi
}

config_wp() {
	echo "Configuring WordPress..."

	#WORDPRESS_CONFIG_PATH="$WORDPRESS_CORE_DIR/wp-config.php"

	#if [ -f $WORDPRESS_CONFIG_PATH ]; then
	#	echo "wp-config.php already exists, so skip it"
	#	return 0
	#fi


	#cp "$WORDPRESS_CORE_DIR/wp-config-sample.php" $WORDPRESS_CONFIG_PATH

	#$DOCKER_EXEC_WP php /var/www/html/wp-cli.phar core install \
	#	--allow-root \
	#	--path="/var/www/html" \
	#	--title="$WORDPRESS_TITLE" \
	#	--admin_user="$WORDPRESS_ADMIN_USER" \
	#	--admin_password="$WORDPRESS_ADMIN_PASS" \
	#	--admin_email="$WORDPRESS_ADMIN_EMAIL" \
	#	--skip-email

	curl --data "weblog_title=$WORDPRESS_TITLE&user_name=$WORDPRESS_ADMIN_USER&admin_password=$WORDPRESS_ADMIN_PASS&admin_password2=$WORDPRESS_ADMIN_PASS&admin_email=$WORDPRESS_ADMIN_EMAIL&blog_public=checked&Submit=submit" "http://localhost:$WORDPRESS_PORT/wp-admin/install.php?step=2" > /dev/null
}

wp_install() {
	$DOCKER_EXEC_WP php /var/www/html/wp-cli.phar plugin install $1 --activate \
		--allow-root \
		--path="/var/www/html"
}

install_plugins() {
	echo "Installing Plugins..."

	if [ ! -d "$WORDPRESS_CORE_DIR/wp-content/plugins/woocommerce" ]; then
		wp_install "woocommerce"
	fi

	if [ ! -d "$WORDPRESS_CORE_DIR/wp-content/plugins/wp-phpmyadmin-extension" ]; then
		wp_install "wp-phpmyadmin-extension"
	fi
}

install_woocommerce_tests_framework() {
	$SCRIPT_DIR/wp-phpunit-install-wc-framework.sh
}

docker_run_containers() {
	$SCRIPT_DIR/wp-phpunit-docker-run.sh
}

check_installation
install_wp
docker_run_containers
create_db
config_wp
install_wp_cli
install_plugins
install_test_suite
install_woocommerce_tests_framework

echo "Done"