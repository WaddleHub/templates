#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Scaffold the project.
echo "[WADDLE] Creating Strapi project."
docker compose exec -T \
    -e WADDLE_DB_USER="${WADDLE_DB_USER}" \
    -e WADDLE_DB_PASSWORD="${WADDLE_DB_PASSWORD}" \
    node sh -c 'npx --yes "create-strapi@{{tags.website.version.raw}}" "{{project_path 'website/src'}}" \
        --typescript --use-npm --install --no-git-init --no-example --skip-cloud --no-run \
        --no-enable-ab-tests \
        {{#if public.mariadb.install}}
        --dbclient mysql --dbhost db --dbport 3306 --dbname "{{public.website.db_name}}" \
        --dbusername "${WADDLE_DB_USER}" --dbpassword "${WADDLE_DB_PASSWORD}"
        {{else}}
        --dbclient sqlite
        {{/if}}'

# Apply configuration .env (persistent secrets, database, mail), and Strapi's server and
# plugin configs with additions (public URL behind nginx, SMTP mail provider).
echo "[WADDLE] Applying configuration."
cp "./website/conf/strapi/.env" "./website/src/.env"
cp "./website/conf/strapi/config/server.ts" "./website/src/config/server.ts"
cp "./website/conf/strapi/config/plugins.ts" "./website/src/config/plugins.ts"

# The SMTP mail provider config/plugins.ts uses when mail is on, pinned to the Strapi release.
echo "[WADDLE] Installing the email provider."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@strapi/provider-email-nodemailer@{{tags.website.version.raw}}"

# Create the admin account. Loading Strapi for this also creates the database schema.
echo "[WADDLE] Creating admin user."
docker compose exec -T -w "{{project_path 'website/src'}}" \
    -e WADDLE_ADMIN_PASSWORD="${WADDLE_ADMIN_PASSWORD}" node sh -c \
    'npx strapi admin:create-user \
        --email "{{public.website.admin_email}}" \
        --password "${WADDLE_ADMIN_PASSWORD}" \
        --firstname "{{public.website.admin_firstname}}"{{#if public.website.admin_lastname}} \
        --lastname "{{public.website.admin_lastname}}"{{/if}}'

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Strapi."
docker compose restart node

# Wait for Strapi to answer its health endpoint, so the build only finishes once the site is up.
# The first start in development mode compiles the TypeScript and prepares the admin panel.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:1337/_health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Strapi..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Strapi failed to start. See: docker compose logs node"
    exit 1
fi
