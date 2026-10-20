#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

if [ -f "./website/src/bin/console" ]; then
    echo "[WADDLE] Running migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" doctrine:migrations:migrate --no-interaction

    echo "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear
fi
