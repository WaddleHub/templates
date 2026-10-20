#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website rollback."

# Clear cache after restore to avoid serving stale compiled templates.
if [ -d "./website/src/phpBB" ]; then
    echo "[WADDLE] Clearing cache."
    docker compose exec -T php php "{{project_path 'website/src'}}/phpBB/bin/phpbbcli.php" cache:purge
fi
