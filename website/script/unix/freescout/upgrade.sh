#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Fetch and checkout the new version tag.
# echo "[WADDLE] Fetching new version."
# git -C "./website/src" fetch --depth=1 origin {{tags.website.version.full_raw}}
# git -C "./website/src" checkout {{tags.website.version.full_raw}}

# Update PHP dependencies. Skip autoloader generation initially — rap2hpoutre/laravel-log-viewer
# references a non-existent src/controllers directory that would break classmap scanning.
echo "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev --ignore-platform-reqs --no-autoloader \
    --working-dir="{{project_path 'website/src'}}"

# Ensure the missing directory exists before generating the autoloader.
mkdir -p "./website/src/vendor/rap2hpoutre/laravel-log-viewer/src/controllers"

echo "[WADDLE] Generating autoloader."
docker compose exec -T php composer dump-autoload --optimize --ignore-platform-reqs \
    --working-dir="{{project_path 'website/src'}}"

# Run database migrations.
echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force

# Clear caches.
echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:clear-cache

echo "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
