$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update Flarum and its extensions.
Write-Host "[WADDLE] Updating dependencies."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }

# Run database migrations.
Write-Host "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" migrate
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Clear caches.
Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

# Disable maintenance mode.
Write-Host "[WADDLE] Taking site out of maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" up
if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
