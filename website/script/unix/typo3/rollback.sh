#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

# Re-run database schema updates against the restored version.
if [ -f "./website/src/vendor/bin/typo3" ]; then
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" database:updateschema || true
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush || true
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" maintenance:disable || true
fi
