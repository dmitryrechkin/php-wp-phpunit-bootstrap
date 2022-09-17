#!/usr/bin/env bash
# See https://raw.githubusercontent.com/wp-cli/scaffold-command/master/templates/install-wp-tests.sh

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_DIR")"; pwd -P)/$(basename "$SCRIPT_DIR")"

if [ -f $SCRIPT_DIR/.env ]; then
	export $(cat $SCRIPT_DIR/.env | xargs)
fi

TMPDIR=${TMPDIR-/tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")
WORDPRESS_CORE_DIR=${WORDPRESS_CORE_DIR-$TMPDIR/dmitryrechkin/wp/www}
WORDPRESS_DB_DIR=${WORDPRESS_DB_DIR-$TMPDIR/dmitryrechkin/wp/db}
WORDPRESS_LOGS_DIR=${WORDPRESS_LOGS_DIR-$TMPDIR/dmitryrechkin/wp/logs}


docker_run_db() {
	echo "Starting Docker Database container..."

	mkdir -p $WORDPRESS_DB_DIR
	docker run --rm --name $WORDPRESS_DB_HOST --env-file $SCRIPT_DIR/.env -p $WORDPRESS_DB_PORT:3306 -v $WORDPRESS_DB_DIR:/var/lib/mysql -d mariadb:latest
	docker exec -it $WORDPRESS_DB_HOST bash -c "echo 127.0.0.1 $WORDPRESS_DB_HOST >> /etc/hosts"

	wait_for "docker exec $WORDPRESS_DB_HOST mysql -uroot -p$MYSQL_ROOT_PASSWORD -e 'select 1'" 30 20
}

docker_run_wordpress() {
	echo "Starting Docker WordPress container..."
	mkdir -p $WORDPRESS_CORE_DIR
	docker run --rm --name $WORDPRESS_HOST --env-file $SCRIPT_DIR/.env -p $WORDPRESS_PORT:80 -v $WORDPRESS_CORE_DIR:/var/www/html --link $WORDPRESS_DB_HOST -d wordpress

	wait_for "ls $WORDPRESS_CORE_DIR/wp-config.php" 60 20
}

wait_for() {
	echo "Waiting for: $1"

	local counter=0
	until bash -c "$1" >/dev/null 2>&1; do
		echo "It is not ready yet, waiting for $2 seconds..."
		sleep $2
		((counter++))
		if [ $counter -gt $3 ]; then
			echo "Timeout..."
			exit
		fi
	done
}

docker_run_containers() {
	docker_run_db
	docker_run_wordpress
}

docker_run_containers
