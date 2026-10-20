$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer audit setting." }

docker compose exec -T php composer update --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }
