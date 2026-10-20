#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

echo "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction

echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force

echo "[WADDLE] Publishing assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" vendor:publish --all --force

echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize:clear
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize

echo "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
