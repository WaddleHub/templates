$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies.
Write-Host "[WADDLE] Updating dependencies."
docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }

# Run database schema updates.
Write-Host "[WADDLE] Running database updates."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" database:updateschema
if ($LASTEXITCODE -ne 0) { throw "Failed to run database updates." }

# Run upgrade wizards.
Write-Host "[WADDLE] Running upgrade wizards."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" upgrade:run --all --no-interaction

# Flush caches.
Write-Host "[WADDLE] Flushing cache."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush
if ($LASTEXITCODE -ne 0) { throw "Failed to flush cache." }

# Disable maintenance mode.
Write-Host "[WADDLE] Disable maintenance mode."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" maintenance:disable
