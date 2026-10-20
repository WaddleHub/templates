#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Next.js and its ESLint config at the pinned version.
echo "[WADDLE] Upgrading Next.js."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "next@{{tags.website.version.raw}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-dev "eslint-config-next@{{tags.website.version.raw}}"

echo "[WADDLE] Restarting Next.js."
docker compose restart node
