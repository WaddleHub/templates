#!/bin/sh -eux

CONF_DIR="{{project_path 'redis/conf'}}"
CONF_FILE="$CONF_DIR/redis.conf"

# Create the log, config and data directories.
mkdir -p "{{project_path 'redis/log'}}" "$CONF_DIR" "{{project_path 'redis/data'}}"

# Publish config files to host directory.
rsync -ru /opt/redis_conf/ "$CONF_DIR/"

# Ensure Redis listens on the project network so the other containers can reach it. This is
# written directly to the config file (rather than set via redis-cli in init.sh) so that it
# takes effect from the very first start, before init.sh runs.
if [ -f "$CONF_FILE" ] && ! grep -q "bind 127.0.0.1 redis" "$CONF_FILE"; then
    echo "bind 127.0.0.1 redis" >> "$CONF_FILE"
fi

exec "${@}" "$CONF_FILE"
