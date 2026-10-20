#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

# The source was restored without its node_modules (left out of the backup), and the database
# with it. Reinstall the dependencies the restored lock file names, then restart Strapi on them.
if [ -f "./website/src/package.json" ]; then
    echo "[WADDLE] Reinstalling dependencies."
    docker compose exec -T -w "{{project_path 'website/src'}}" node npm ci --no-audit --no-fund

    echo "[WADDLE] Restarting Strapi."
    docker compose restart node
fi
