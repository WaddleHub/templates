#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies.
echo "[WADDLE] Upgrading Gatsby."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "gatsby@{{tags.website.version.raw}}"

# Clear cache & restart.
echo "[WADDLE] Clearing the Gatsby cache."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx gatsby clean

echo "[WADDLE] Restarting Gatsby."
docker compose restart node
