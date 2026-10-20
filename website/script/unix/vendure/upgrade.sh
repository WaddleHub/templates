#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Vendure's packages at the pinned version (they're released together).
echo "[WADDLE] Upgrading Vendure."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-exact \
    "@vendure/core@{{tags.website.version.raw}}" \
    "@vendure/email-plugin@{{tags.website.version.raw}}" \
    "@vendure/asset-server-plugin@{{tags.website.version.raw}}" \
    "@vendure/graphiql-plugin@{{tags.website.version.raw}}" \
    "@vendure/dashboard@{{tags.website.version.raw}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-dev --save-exact "@vendure/cli@{{tags.website.version.raw}}"

# Generate a migration for the new release's database changes, if it has any. The server runs
# pending migrations on start.
echo "[WADDLE] Generating the database migration."
docker compose exec -T -w "{{project_path 'website/src'}}" node \
    npx vendure migrate --generate "upgrade-{{tags.website.version.raw}}"

echo "[WADDLE] Restarting Vendure."
docker compose restart node
