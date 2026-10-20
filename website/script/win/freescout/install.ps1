$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download FreeScout via git and install its PHP dependencies, from inside the php container for
# accurate permissions. Skip autoloader generation initially cause rap2hpoutre/laravel-log-viewer
# references a non-existent src/controllers directory that would break classmap scanning.
# Afterwards, drop the git metadata, so the project's repository tracks website/src as plain files.
Write-Host "[WADDLE] Downloading FreeScout version {{tags.website.version.full_raw}}."
$installScript = @'
set -eux
git clone --depth=1 --branch={{tags.website.version.full_raw}} https://github.com/freescout-help-desk/freescout.git "{{project_path 'website/src'}}"
composer install --no-dev --ignore-platform-reqs --no-autoloader --working-dir="{{project_path 'website/src'}}"
mkdir -p "{{project_path 'website/src'}}/vendor/rap2hpoutre/laravel-log-viewer/src/controllers"
composer dump-autoload --optimize --ignore-platform-reqs --working-dir="{{project_path 'website/src'}}"
find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +
'@
$installScript | docker compose exec -i php sh -c "tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to download FreeScout." }

# Apply Waddle configuration.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/freescout/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Run database migrations.
Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Create admin user.
Write-Host "[WADDLE] Creating admin user."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:create-user `
    --role=admin `
    --firstName="{{public.website.admin_firstname}}" `
    --lastName="{{public.website.admin_lastname}}" `
    --email="{{public.website.admin_email}}" `
    --password="$env:WADDLE_ADMIN_PASSWORD"
if ($LASTEXITCODE -ne 0) { throw "Failed to create admin user." }

# Clear caches.
Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:clear-cache
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
