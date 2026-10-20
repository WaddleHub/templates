#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

PHPBB_SRC="./website/src/phpBB"
PHPBB_SRC_CONTAINER="{{project_path 'website/src'}}/phpBB"

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Clone the phpBB repository from inside the php container rather than on the host: a host-side
# git clone leaves the tree owned by whatever account ran Waddle, and a rootless-Docker
# container's root can create new files alongside them but can never chown them afterward.
echo "[WADDLE] Downloading phpBB version {{tags.website.version.full_raw}}."
docker compose exec -T php git clone --depth=1 --branch={{tags.website.version.full_raw}} \
    https://github.com/phpbb/phpbb.git "{{project_path 'website/src'}}"

# Install PHP dependencies.
echo "[WADDLE] Installing dependencies."
docker compose exec -T php composer install --no-dev \
    --working-dir="${PHPBB_SRC_CONTAINER}"

# Drop the git metadata, so the project's repository tracks website/src as plain files.
echo "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +

# Copy install configuration.
echo "[WADDLE] Copying install configuration."
cp "./website/conf/phpbb/install.yml" "${PHPBB_SRC}/install.yml"

# Run the phpBB CLI installer.
echo "[WADDLE] Running phpBB CLI installer."
docker compose exec -T php sh -c \
    "cd '${PHPBB_SRC_CONTAINER}' && php install/phpbbcli.php install install.yml"

# Remove temporary install config.
rm -f "${PHPBB_SRC}/install.yml"

# Remove the install directory.
echo "[WADDLE] Removing install directory."
rm -rf "${PHPBB_SRC}/install"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
