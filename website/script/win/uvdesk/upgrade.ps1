$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

Write-Host "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }

Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" doctrine:migrations:migrate --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
