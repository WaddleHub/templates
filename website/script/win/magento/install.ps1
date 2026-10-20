$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Disable Composer's block-insecure audit to allow installation of Magento's dev
# dependencies (e.g. phpunit) that carry security advisories unrelated to runtime.
docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer." }

# Download Magento.
Write-Host "[WADDLE] Downloading Magento version {{tags.website.version.full_raw}}"
docker compose exec -T php composer create-project `
    magento/project-community-edition:{{tags.website.version.full_raw}} `
    --repository=https://repo.magento.com/ "{{project_path 'website/src'}}" --no-interaction --prefer-dist
if ($LASTEXITCODE -ne 0) { throw "Failed to download Magento." }
docker compose exec -T php composer require magento/composer-root-update-plugin -d "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install composer-root-update-plugin." }

# Drop internal Composer cache directory (we will be using a directory shared
# between all projects instead, to speed up subsequent installations).
Write-Host "[WADDLE] Updating Composer cache and configuration."
docker compose exec -T php sh -c "rm -rf '{{project_path 'website/src'}}/var/composer_home/cache' && mkdir -p '{{project_path 'website/src'}}/var/composer_home'"
if ($LASTEXITCODE -ne 0) { throw "Failed to reset Composer home directory." }
docker compose exec -T php ln -sf "{{project_path 'composer/conf/home/auth.json'}}" "{{project_path 'website/src'}}/var/composer_home/auth.json"
if ($LASTEXITCODE -ne 0) { throw "Failed to create Composer auth.json symlink." }
docker compose exec -T php ln -sf "{{paths.shared}}/cache/composer" "{{project_path 'website/src'}}/var/composer_home/cache"
if ($LASTEXITCODE -ne 0) { throw "Failed to create Composer cache symlink." }

Write-Host "[WADDLE] Installing."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:install `
    --admin-firstname="{{public.website.admin_firstname}}" `
    --admin-lastname="{{public.website.admin_lastname}}" `
    --language="{{public.website.language}}" `
    --currency="{{public.website.currency}}" `
    --use-rewrites=1 `
    --backend-frontname="{{public.website.admin_route}}" `
    --admin-email="{{public.website.admin_email}}" `
    --admin-user="{{public.website.admin_username}}" `
    --admin-password="$env:WADDLE_ADMIN_PASSWORD" `
    --timezone={{advanced.website.magento_timezone}} `
    --base-url=http://{{public.website.url}}/ `
    --db-host=db `
    --db-name={{public.website.db_name}} `
    --db-user="$env:WADDLE_DB_USER" `
    --db-password="$env:WADDLE_DB_PASSWORD" `
    --opensearch-host=opensearch `
    --opensearch-port=9200 `
    --search-engine=opensearch{{#if ssl.enabled}} `
    --use-secure=1 `
    --use-secure-admin=1 `
    --base-url-secure=https://{{public.website.url}}/{{/if}}
if ($LASTEXITCODE -ne 0) { throw "Failed to install Magento." }

# Setup sample data.
{{#if public.website.deploy_sample_data}}
# Clone or update sample data. NOTE: sampledata:deploy avoided due to increased RAM consumption.
Write-Host "[WADDLE] Fetching sample data."
docker compose exec -T php sh -c "cd '{{project_path 'website/src'}}' && if [ -d sample-data/.git ]; then git -C sample-data pull --ff-only; else git clone https://github.com/magento/magento2-sample-data sample-data; fi"
if ($LASTEXITCODE -ne 0) { throw "Failed to fetch sample data." }
docker compose exec -T php mkdir -p "{{project_path 'website/src'}}/app/code"
if ($LASTEXITCODE -ne 0) { throw "Failed to create app/code directory." }
Write-Host "[WADDLE] Installing sample data."
docker compose exec -T php php -f "{{project_path 'website/src'}}/sample-data/dev/tools/build-sample-data.php" -- --ce-source="{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install sample data." }
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php mkdir -p "{{project_path 'website/src'}}/sample-data/pub/media/catalog/product/cache"
if ($LASTEXITCODE -ne 0) { throw "Failed to create sample-data media cache directory." }
{{/if}}

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
