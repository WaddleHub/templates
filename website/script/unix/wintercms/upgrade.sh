#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# See install.sh.
docker compose exec -T php composer config -g audit.block-insecure false

echo "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction

echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate

echo "[WADDLE] Mirroring public assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" winter:mirror public --relative

echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear

echo "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
