#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

if [ -f "./website/src/artisan" ]; then
    echo "[WADDLE] Running migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate

    echo "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear

    echo "[WADDLE] Disabling maintenance mode."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
fi
