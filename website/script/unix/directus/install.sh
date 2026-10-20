#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Directus has no project scaffold: a Directus project is a package.json depending on the
# `directus` package, plus its .env.
echo "[WADDLE] Applying configuration."
cp "./website/conf/directus/package.json" "./website/src/package.json"
cp "./website/conf/directus/src.gitignore" "./website/src/.gitignore"
cp "./website/conf/directus/.env" "./website/src/.env"

# Install Directus.
echo "[WADDLE] Installing Directus."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-exact "directus@{{tags.website.version.raw}}"

# Install the database schema and create the admin account (from ADMIN_EMAIL/ADMIN_PASSWORD),
# the project name and owner. Passed as environment variables, so the admin password stays
# out of the .env.
echo "[WADDLE] Installing the database and creating the admin user."
docker compose exec -T -w "{{project_path 'website/src'}}" \
    -e ADMIN_EMAIL="{{public.website.admin_email}}" \
    -e ADMIN_PASSWORD="${WADDLE_ADMIN_PASSWORD}" \
    -e PROJECT_OWNER="{{public.website.admin_email}}" \
    {{#if public.website.title}}
    -e PROJECT_NAME="{{public.website.title}}" \
    {{/if}}
    node npx directus bootstrap

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Directus."
docker compose restart node

# Wait for Directus to answer its ping endpoint, so the build only finishes once the site is up.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:8055/server/ping').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Directus..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Directus failed to start. See: docker compose logs node"
    exit 1
fi
