$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Fetch and checkout the new version tag.
# Write-Host "[WADDLE] Fetching new version."
# git -C "./website/src" fetch --depth=1 origin {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to fetch new version." }
# git -C "./website/src" checkout {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to checkout new version." }

# Update PHP dependencies. Skip autoloader generation initially — rap2hpoutre/laravel-log-viewer
# references a non-existent src/controllers directory that would break classmap scanning.
Write-Host "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev --ignore-platform-reqs --no-autoloader `
    --working-dir="{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }

# Ensure the missing directory exists before generating the autoloader.
New-Item -ItemType Directory -Path "./website/src/vendor/rap2hpoutre/laravel-log-viewer/src/controllers" -Force | Out-Null

Write-Host "[WADDLE] Generating autoloader."
docker compose exec -T php composer dump-autoload --optimize --ignore-platform-reqs `
    --working-dir="{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to generate autoloader." }

# Run database migrations.
Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Clear caches.
Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" freescout:clear-cache
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

Write-Host "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
