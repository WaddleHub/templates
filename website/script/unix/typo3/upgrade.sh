#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies.
echo "[WADDLE] Updating dependencies."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction

# Run database schema updates.
echo "[WADDLE] Running database updates."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" database:updateschema

# Run upgrade wizards.
echo "[WADDLE] Running upgrade wizards."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" upgrade:run --all --no-interaction || true

# Flush caches.
echo "[WADDLE] Flushing cache."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush

# Disable maintenance mode.
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" maintenance:disable || true
