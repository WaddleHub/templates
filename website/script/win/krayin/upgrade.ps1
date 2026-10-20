$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

Write-Host "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }

Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate --force
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

Write-Host "[WADDLE] Publishing assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" vendor:publish --all --force
if ($LASTEXITCODE -ne 0) { throw "Failed to publish assets." }

Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize
if ($LASTEXITCODE -ne 0) { throw "Failed to optimize." }

Write-Host "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
