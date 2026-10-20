#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

if [ -f "./website/src/artisan" ]; then
    echo "[WADDLE] Running migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force

    echo "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:clear-cache

    echo "[WADDLE] Disabling maintenance mode."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
fi
