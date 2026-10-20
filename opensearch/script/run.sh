#!/bin/sh -eux

CONFIG_PATH="{{project_path 'opensearch/conf'}}"
LOG_PATH="{{project_path 'opensearch/log'}}"
DATA_PATH="{{project_path 'opensearch/data'}}"

# Create local directories.
mkdir -p "$CONFIG_PATH" "$LOG_PATH" "$DATA_PATH"

# Publish updated config files to host directory.
rsync -ru "{{public.opensearch.prefix}}/config/" "$CONFIG_PATH/"

# Append custom configuration rules to opensearch.yml. The leading newline guards against the
# bundled opensearch.yml not ending in one, which would otherwise merge our first line onto its last.
# #
# # Opensearch does not read custom config files from the config directory by default. This is
# # effectively copying our custom config into the bundled opensearch.yml.
if [ -f "$CONFIG_PATH/opensearch.yml" ] && ! grep -q "$LOG_PATH" "$CONFIG_PATH/opensearch.yml"; then
    { printf '\n'; cat "$CONFIG_PATH/opensearch.custom.yml"; } >> "$CONFIG_PATH/opensearch.yml"
fi

# Avoid permission drop if already running as an unprivileged user.
if [ "$(id -u)" != "0" ]; then
    exec "${@}"
fi

# OpenSearch's own bootstrap hard-refuses to run as root, asserting logs and data dir are
# owned by the daemon user.
chown -R {{get_daemon_user public.opensearch.docker}}:{{get_daemon_group public.opensearch.docker}} \
    "$LOG_PATH" "$DATA_PATH"

# $CONFIG_PATH also needs to be daemon-writable, not just log/data. On first run OpenSearch
# creates its own opensearch.keystore directly inside the config directory, which fatals with
# AccessDeniedException otherwise. The config directory, unlike log/data, is created by the
# system user during build time and contains files we expect the system user to have access
# to. Because of this, we must grant everyone read/write/execute access, to ensure both the
# system user and the daemon always have access to the config directory. If you feel
# uncomfortable with this you can tweak this to fit your situation, the below aims to cover
# scenarios or running the docker daemon locally, on remote shared servers, both in root and
# rootless mode.
chmod o+rwx "$CONFIG_PATH"

# Drop privileges and run as the daemon user.
exec gosu {{get_daemon_user public.opensearch.docker}}:{{get_daemon_group public.opensearch.docker}} "${@}"
