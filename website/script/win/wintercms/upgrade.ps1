$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# See install.ps1.
docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer." }

Write-Host "[WADDLE] Updating packages."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }

Write-Host "[WADDLE] Running migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

Write-Host "[WADDLE] Mirroring public assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" winter:mirror public --relative
if ($LASTEXITCODE -ne 0) { throw "Failed to mirror public assets." }

Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

Write-Host "[WADDLE] Disabling maintenance mode."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
