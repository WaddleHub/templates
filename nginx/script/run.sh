#!/bin/sh -eux

PID_FILE="{{project_path 'nginx/log/nginx.pid'}}"
ACCESS_LOG="{{project_path 'nginx/log/access.log'}}"
ERROR_LOG="{{project_path 'nginx/log/error.log'}}"

# Create directory for certificates & logs.
mkdir -p "{{project_path 'ssl'}}" "{{project_path 'nginx/log'}}" "{{project_path 'nginx/data/client_body_temp'}}" "{{project_path 'nginx/data/proxy_temp'}}" "{{project_path 'nginx/data/fastcgi_temp'}}" "{{project_path 'nginx/data/uwsgi_temp'}}" "{{project_path 'nginx/data/scgi_temp'}}" "{{project_path 'nginx/conf'}}" "{{project_path 'nginx/conf/extras'}}"

if [ ! -f "$PID_FILE" ]; then
    touch "$PID_FILE"
fi

if [ ! -f "$ACCESS_LOG" ]; then
    touch "$ACCESS_LOG"
fi

if [ ! -f "$ERROR_LOG" ]; then
    touch "$ERROR_LOG"
fi

# Publish updated config files to host directory.
rsync -ru /opt/nginx_conf/ "{{project_path 'nginx/conf'}}/"

# By default, run the nginx daemon as an unprivileged user.
DAEMON_USER="{{get_daemon_user public.nginx.docker}} {{get_daemon_group public.nginx.docker}}"

# In Docker rootless mode, let nginx run as root if it can't chown worker temp dirs.
if [ "$(id -u)" = "0" ] \
    && ! chown {{get_daemon_user public.nginx.docker}}:{{get_daemon_group public.nginx.docker}} "{{project_path 'nginx/data/client_body_temp'}}" 2>/dev/null; then
    DAEMON_USER="root"
fi

if [ "$#" = "3" ] && [ "$2" = "-g" ]; then
    set -- "$1" "$2" "$3 user $DAEMON_USER;"
fi

exec "${@}"
