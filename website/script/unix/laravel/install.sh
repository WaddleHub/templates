#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

docker compose exec -T php composer create-project \
    laravel/laravel:"{{tags.website.version.major}}.{{tags.website.version.minor}}.*" \
    "{{project_path 'website/src'}}" --no-interaction

# Apply configuration directives from website/conf/laravel/.env and remove the default SQLite file.
echo "[WADDLE] Applying configuration."
rm -f "./website/src/database/database.sqlite"
cp "./website/conf/laravel/.env" "./website/src/.env"

{{#unless public.mariadb.install}}
# No database configured for this project, recreate the SQLite file in storage/app.
docker compose exec -T php touch "{{project_path 'website/src/storage/app/database.sqlite'}}"
{{/unless}}

echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
