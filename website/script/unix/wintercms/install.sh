#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Winter CMS 1.2 requires Laravel 9, and Composer 2.10's default audit.block-insecure skips every
# stable laravel/framework 9.x release (all have security advisories), so it resolves an
# incompatible 9.x-dev instead. Allow them in order to proceed, only affects this project.
docker compose exec -T php composer config -g audit.block-insecure false

# Download Winter CMS via Composer. Use --no-scripts to skip the interactive
# winter:install post-install wizard; we configure the environment manually.
echo "[WADDLE] Downloading Winter CMS version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project \
    wintercms/winter:{{tags.website.version.full_raw}} "{{project_path 'website/src'}}" \
    --no-interaction --no-scripts

# Apply configuration.
echo "[WADDLE] Applying configuration."
cp "./website/conf/wintercms/.env" "./website/src/.env"

# Run database migrations.
echo "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate

# Mirror public assets.
echo "[WADDLE] Mirroring public assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" winter:mirror public --relative

# Create admin user.
echo "[WADDLE] Creating admin user."

# Note: user:create has a bug where it crashes on the success message after creating the
# user ($role variable is undefined in the info line). The user IS created successfully
# before the crash, so we suppress the exit code.
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" user:create \
    "{{public.website.admin_email}}" \
    --fname="{{public.website.admin_firstname}}" \
    --lname="{{public.website.admin_lastname}}" \
    --password="${WADDLE_ADMIN_PASSWORD}" \
    --role=developer \
    --force || true

# Clear caches.
echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
