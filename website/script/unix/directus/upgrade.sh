#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

echo "[WADDLE] Upgrading Directus."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-exact "directus@{{tags.website.version.raw}}"

# The node service bootstraps Directus before starting it, which migrates the database to the
# new release.
echo "[WADDLE] Restarting Directus."
docker compose restart node
