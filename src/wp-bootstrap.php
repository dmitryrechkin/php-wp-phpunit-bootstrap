<?php

define('WP_BOOTSTRAP', true);
define('VENDOR_DIR', realpath(__DIR__ . '/../..'));

include_once(VENDOR_DIR . 'dmitryrechkin/src/bootstrap.php');

global $WORDPRESS_CORE_DIR;

$TMPDIR = rtrim(sys_get_temp_dir(), '/\\');
$WORDPRESS_TESTS_DIR = $TMPDIR . '/dmitryrechkin/wp/tests-lib';
$WORDPRESS_CORE_DIR = $TMPDIR . '/dmitryrechkin/wp/www';

if (!file_exists($WORDPRESS_TESTS_DIR . '/includes/functions.php')) {
	echo "Could not find $WORDPRESS_TESTS_DIR/includes/functions.php, have you run vendor/bin/wp-install.sh ?" . PHP_EOL; // WPCS: XSS ok.
	exit(1);
}

// Give access to tests_add_filter() function.
require_once $WORDPRESS_TESTS_DIR . '/includes/functions.php';

/**
 * Manually load required plugins
 */
function _load_plugins(): void {
	global $WORDPRESS_CORE_DIR;

	require_once $WORDPRESS_CORE_DIR . '/wp-content/plugins/woocommerce/woocommerce.php';
}

tests_add_filter('muplugins_loaded', '_load_plugins');

// Start up the WP testing environment.
require $WORDPRESS_TESTS_DIR . '/includes/bootstrap.php';
