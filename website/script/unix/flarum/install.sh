#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download Flarum via Composer.
echo "[WADDLE] Downloading Flarum version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project \
    flarum/flarum:{{tags.website.version.full_raw}} "{{project_path 'website/src'}}" --no-interaction

# Copy install configuration.
echo "[WADDLE] Copying install configuration."
cp "./website/conf/flarum/install.yml" "./website/src/install.yml"

# Run the Flarum CLI installer.
echo "[WADDLE] Running Flarum installer."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" install \
    --file="{{project_path 'website/src'}}/install.yml"

# Remove temporary install config.
rm -f "./website/src/install.yml"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
