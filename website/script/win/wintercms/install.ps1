$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Winter CMS 1.2 requires Laravel 9, and Composer 2.10's default audit.block-insecure skips every
# stable laravel/framework 9.x release (all have security advisories), so it resolves an
# incompatible 9.x-dev instead. Allow them in order to proceed, only affects this project.
docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer." }

# Download Winter CMS via Composer. Use --no-scripts to skip the interactive
# winter:install post-install wizard; we configure the environment manually.
Write-Host "[WADDLE] Downloading Winter CMS version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project wintercms/winter:{{tags.website.version.full_raw}} `
    "{{project_path 'website/src'}}" --no-interaction --no-scripts
if ($LASTEXITCODE -ne 0) { throw "Failed to download Winter CMS." }

# Apply configuration.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/wintercms/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Run database migrations.
Write-Host "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Mirror public assets.
Write-Host "[WADDLE] Mirroring public assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" winter:mirror public --relative
if ($LASTEXITCODE -ne 0) { throw "Failed to mirror public assets." }

# Create admin user.
Write-Host "[WADDLE] Creating admin user."
# Note: user:create has a bug where it crashes on the success message after creating the
# user ($role variable is undefined in the info line). The user IS created successfully
# before the crash, so we suppress the exit code.
$ErrorActionPreference = "Continue"
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" user:create `
    "{{public.website.admin_email}}" `
    --fname="{{public.website.admin_firstname}}" `
    --lname="{{public.website.admin_lastname}}" `
    --password="$env:WADDLE_ADMIN_PASSWORD" `
    --role=developer `
    --force
$ErrorActionPreference = "Stop"

# Clear caches.
Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
