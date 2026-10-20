#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download FreeScout via git, from inside the php container for accurate permissions.
echo "[WADDLE] Downloading FreeScout version {{tags.website.version.full_raw}}."
docker compose exec -T php git clone --depth=1 --branch={{tags.website.version.full_raw}} \
    https://github.com/freescout-help-desk/freescout.git "{{project_path 'website/src'}}"

# Install PHP dependencies. Skip autoloader generation initially — rap2hpoutre/laravel-log-viewer
# references a non-existent src/controllers directory that would break classmap scanning.
echo "[WADDLE] Installing dependencies."
docker compose exec -T php composer install --no-dev --ignore-platform-reqs --no-autoloader \
    --working-dir="{{project_path 'website/src'}}"

# Create the missing directory before generating the autoloader (in-container, same reasoning as
# the git clone above).
docker compose exec -T php mkdir -p \
    "{{project_path 'website/src'}}/vendor/rap2hpoutre/laravel-log-viewer/src/controllers"

echo "[WADDLE] Generating autoloader."
docker compose exec -T php composer dump-autoload --optimize --ignore-platform-reqs \
    --working-dir="{{project_path 'website/src'}}"

# Drop the git metadata, so the project's repository tracks website/src as plain files.
echo "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +

# Apply Waddle configuration.
echo "[WADDLE] Applying configuration."
cp "./website/conf/freescout/.env" "./website/src/.env"

# Run database migrations.
echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force

# Create admin user.
echo "[WADDLE] Creating admin user."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:create-user \
    --role=admin \
    --firstName="{{public.website.admin_firstname}}" \
    --lastName="{{public.website.admin_lastname}}" \
    --email="{{public.website.admin_email}}" \
    --password="${WADDLE_ADMIN_PASSWORD}"

# Clear caches.
echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:clear-cache

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
