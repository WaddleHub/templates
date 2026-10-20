#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update Flarum and its extensions.
echo "[WADDLE] Updating dependencies."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction

# Run database migrations.
echo "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" migrate

# Clear caches.
echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" cache:clear

# Disable maintenance mode.
echo "[WADDLE] Taking site out of maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" up
