#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear

echo "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction

echo "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" doctrine:migrations:migrate --no-interaction

echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear
