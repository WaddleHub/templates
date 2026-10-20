#!/bin/sh -eux

DATA_PATH="{{project_path 'mariadb/data'}}"
LOG_PATH="{{project_path 'mariadb/log'}}"

mkdir -p "$LOG_PATH" "$DATA_PATH" "{{project_path 'mariadb/conf/conf.d'}}"

IS_ROOT=0
CAN_CHOWN=0

if [ "$(id -u)" = "0" ]; then
    IS_ROOT=1

    if chown {{get_daemon_user public.mariadb.docker}}:{{get_daemon_group public.mariadb.docker}} "$DATA_PATH" "$LOG_PATH"; then
        CAN_CHOWN=1
    fi
fi

if [ "$CAN_CHOWN" = "0" ]; then
    # Rootless Docker: container "root" cannot chown these paths to another identity, so they
    # stay owned by the current (root) user. mariadbd refuses to start as uid 0 without an
    # explicit --user though, so acknowledge that identity instead of trying to switch into one
    # that cannot access its own data/log directories.
    ARGS=""

    for ARG in "$@"; do
        case "$ARG" in
            --user=*)
                if [ "$IS_ROOT" = "1" ]; then
                    ARGS="${ARGS} --user=root"
                fi
                ;;
            *) ARGS="${ARGS} ${ARG}" ;;
        esac
    done

    # Apply updated list of arguments.
    set -- $ARGS
fi

exec "$@"
