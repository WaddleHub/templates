#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

# Re-install dependencies and restart.
if [ -f "./website/src/package.json" ]; then
    echo "[WADDLE] Reinstalling dependencies."
    docker compose exec -T -w "{{project_path 'website/src'}}" node npm ci --no-audit --no-fund

    echo "[WADDLE] Restarting Astro."
    docker compose restart node
fi
