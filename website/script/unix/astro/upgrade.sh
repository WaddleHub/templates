#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Astro at the pinned version, and the Node adapter at its newest version
# supporting it.
echo "[WADDLE] Upgrading Astro."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "astro@{{tags.website.version.raw}}"
ADAPTER_VERSION="$(docker compose exec -T -w "{{project_path 'website/src'}}" node \
    node "{{project_path 'website/conf/astro/adapter-version.cjs'}}")"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@astrojs/node@${ADAPTER_VERSION}"

# Regenerate the website's types for the new release & restart.
echo "[WADDLE] Syncing Astro's generated types."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx astro sync

echo "[WADDLE] Restarting Astro."
docker compose restart node
