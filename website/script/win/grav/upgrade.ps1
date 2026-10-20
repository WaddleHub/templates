$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

docker compose exec -T php "{{project_path 'website/src'}}/bin/gpm" selfupgrade -f
if ($LASTEXITCODE -ne 0) { throw "Failed to self-upgrade Grav." }
docker compose exec -T php "{{project_path 'website/src'}}/bin/gpm" update
if ($LASTEXITCODE -ne 0) { throw "Failed to update Grav plugins." }
