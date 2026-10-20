$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

Write-Host "[WADDLE] Downloading Laravel."
docker compose exec -T php composer create-project laravel/laravel:"{{tags.website.version.major}}.{{tags.website.version.minor}}.*" `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Laravel." }

# The skeleton's own composer.json "post-create-project-cmd" scripts already ran as part of the
# command above: copied .env.example to .env, generated a throwaway APP_KEY, touched
# database/database.sqlite and migrated against it. All of that is discarded below in favour of
# Waddle's own persistent APP_KEY and (when MariaDB is enabled) the project's real database — the
# default sqlite file is removed outright since database/ otherwise holds real, git-tracked source
# (migrations, factories, seeders) that must stay that way, not something this leftover file should
# share the daemon-owned chown below with.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php rm -f "{{project_path 'website/src/database/database.sqlite'}}"
docker compose exec -T php cp "{{project_path 'website/conf/laravel/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

{{#unless public.mariadb.install}}
# No database configured for this project, see website/conf/laravel/.env for why the SQLite file
# lives under storage/app instead of the default database/database.sqlite. SQLite requires the
# target file to already exist before Laravel's PDO connection will use it.
docker compose exec -T php touch "{{project_path 'website/src/storage/app/database.sqlite'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to create the SQLite database file." }
{{/unless}}

Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
