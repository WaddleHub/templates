#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Vendure's own scaffolder (@vendure/create) at the pinned version. Its
# prompt-free mode (`--ci`) only offers SQLite or PostgreSQL, so it creates the project with
# SQLite, which is switched to MariaDB below. It also builds and fills a SQLite database, which is
# removed again.
echo "[WADDLE] Scaffolding the Vendure project."
docker compose exec -T -w "{{project_path 'website'}}" node \
    npx --yes "@vendure/create@{{tags.website.version.raw}}" src --ci --use-npm --log-level info

# Name the website's package after the project, then switch to MariaDB. Remove the SQLite
# database, its migration, the sample product images it imported and its driver then and add
# th MariaDB driver.
echo "[WADDLE] Switching the database to MariaDB."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
rm -f ./website/src/vendure.sqlite ./website/src/src/migrations/*.ts
rm -rf ./website/src/static/assets/source/* ./website/src/static/assets/preview/* \
    ./website/src/static/assets/cache/*
docker compose exec -T -w "{{project_path 'website/src'}}" node npm uninstall --no-audit --no-fund \
    better-sqlite3
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-exact mysql2

# Apply configuration: the .env, and the vendure-config.ts (with its environment.d.ts) and
# vite.config.mts reading it.
echo "[WADDLE] Applying configuration."
cp "./website/conf/vendure/.env" "./website/src/.env"
cp "./website/conf/vendure/vendure-config.ts" "./website/src/src/vendure-config.ts"
cp "./website/conf/vendure/environment.d.ts" "./website/src/src/environment.d.ts"
cp "./website/conf/vendure/vite.config.mts" "./website/src/vite.config.mts"

# Create the database schema and the shop's initial data (and sample products), from the data
# files that come with @vendure/create.
echo "[WADDLE] Installing the database."
docker compose exec -T -w /tmp node npm pack --silent "@vendure/create@{{tags.website.version.raw}}"
docker compose exec -T -w /tmp node sh -c \
    'rm -rf /tmp/vendure-create && mkdir /tmp/vendure-create && tar -xzf vendure-create-*.tgz -C /tmp/vendure-create && rm vendure-create-*.tgz'
docker compose exec -T -w "{{project_path 'website/src'}}" node \
    node "{{project_path 'website/conf/vendure/setup.cjs'}}" /tmp/vendure-create/package/assets \
    {{#if public.website.deploy_sample_data}}true{{else}}false{{/if}}
docker compose exec -T node rm -rf /tmp/vendure-create

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Vendure."
docker compose restart node

# Wait for Vendure to answer its health check, so the build only finishes once the site is up.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Vendure..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Vendure failed to start. See: docker compose logs node"
    exit 1
fi
