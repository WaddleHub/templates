#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Disable Composer's block-insecure audit to allow installation of Magento's dev
# dependencies (e.g. phpunit) that carry security advisories unrelated to runtime.
docker compose exec -T php composer config -g audit.block-insecure false

# Download Magento.
echo "[WADDLE] Downloading Magento version {{tags.website.version.full_raw}}"
docker compose exec -T php composer create-project \
    magento/project-community-edition:{{tags.website.version.full_raw}} \
    --repository=https://repo.magento.com/ ./ --no-interaction --prefer-dist \
    -d "{{project_path 'website/src'}}"
docker compose exec -T php composer require magento/composer-root-update-plugin \
    -d "{{project_path 'website/src'}}"

# Drop internal Composer cache directory (we will be using a directory shared
# between all projects instead, to speed up subsequent installations).
echo "[WADDLE] Updating Composer cache and configuration."
rm -rf "./website/src/var/composer_home/cache"
mkdir -p "./website/src/var/composer_home"
ln -sf "../../../../composer/conf/home/auth.json" "./website/src/var/composer_home/auth.json"
ln -sf "{{paths.shared}}/cache/composer" "./website/src/var/composer_home/cache"

echo "[WADDLE] Installing."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:install \
        --admin-firstname="{{public.website.admin_firstname}}" \
        --admin-lastname="{{public.website.admin_lastname}}" \
        --language="{{public.website.language}}" \
        --currency="{{public.website.currency}}" \
        --use-rewrites=1 \
        --backend-frontname="{{public.website.admin_route}}" \
        --admin-email="{{public.website.admin_email}}" \
        --admin-user="{{public.website.admin_username}}" \
        --admin-password="${WADDLE_ADMIN_PASSWORD}" \
        --timezone={{advanced.website.magento_timezone}} \
        --base-url=http://{{public.website.url}}/ \
        --db-host=db \
        --db-name={{public.website.db_name}} \
        --db-user="${WADDLE_DB_USER}" \
        --db-password="${WADDLE_DB_PASSWORD}" \
        --opensearch-host=opensearch \
        --opensearch-port=9200 \
        --search-engine=opensearch{{#if ssl.enabled}} \
        --use-secure=1 \
        --use-secure-admin=1 \
        --base-url-secure=https://{{public.website.url}}/{{/if}}

# Setup sample data.
{{#if public.website.deploy_sample_data}}
if [ -z "$(ls -A "./website/src/sample-data" 2>/dev/null)" ]; then
    echo "[WADDLE] Cloning sample data."
    # NOTE: sampledata:deploy avoided due to increased RAM consumption.
    git clone https://github.com/magento/magento2-sample-data "./website/src/sample-data"
else
    echo "[WADDLE] Updating sample data."
    git -C "./website/src/sample-data" pull --ff-only
fi

if [ ! -d "./website/src/app/code" ] && [ ! -f "./website/src/app/code" ]; then
    mkdir -p "./website/src/app/code"
fi

echo "[WADDLE] Installing sample data."
docker compose exec -T php php -f "{{project_path 'website/src'}}/sample-data/dev/tools/build-sample-data.php" \
    -- --ce-source="{{project_path 'website/src'}}"

# Ensure that the sample data media cache dir exists, so chown -R can reach it below.
mkdir -p "./website/src/sample-data/pub/media/catalog/product/cache"
{{/if}}

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
#
# NOTE: We always report the chown as a success because on certain setups, chowning some resources
# might fail and it's harmless in those cases.
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}} \
    || true
