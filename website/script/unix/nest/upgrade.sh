#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Nest at the pinned version (its packages are released together).
echo "[WADDLE] Upgrading Nest."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@nestjs/common@{{tags.website.version.raw}}" \
    "@nestjs/core@{{tags.website.version.raw}}" \
    "@nestjs/platform-express@{{tags.website.version.raw}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-dev "@nestjs/testing@{{tags.website.version.raw}}" \
    "@nestjs/cli@{{tags.website.version.major}}" "@nestjs/schematics@{{tags.website.version.major}}"

echo "[WADDLE] Restarting Nest."
docker compose restart node
