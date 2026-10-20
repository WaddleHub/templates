#!/bin/sh -eux

DATA_PATH="{{project_path 'mariadb/data'}}"

echo "[WADDLE NOTICE] Starting MariaDB initializer."

if [ ! -d "$DATA_PATH/mysql" ]; then
    mkdir -p "$DATA_PATH"

    DAEMON_USER_FLAG=""

    # Only request a daemon-user switch if we can actually chown the datadir to that user.
    # Rootless Docker reports "id -u" = 0 for container "root" but cannot chown to another
    # identity, and mariadb-install-db does that chown itself when --user is passed.
    if [ "$(id -u)" = "0" ] && chown {{get_daemon_user public.mariadb.docker}} "$DATA_PATH"; then
        DAEMON_USER_FLAG="--user={{get_daemon_user public.mariadb.docker}}"
    fi

    if ! {{public.mariadb.prefix}}/scripts/mariadb-install-db \
            --basedir="{{public.mariadb.prefix}}" \
            --datadir="$DATA_PATH" \
            $DAEMON_USER_FLAG; then
        echo "[WADDLE ERROR] Failed to initialize database."
        exit 1
    fi
fi
