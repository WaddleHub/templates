$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

if (Test-Path "./website/src/bin/console" -PathType Leaf) {
    Write-Host "[WADDLE] Running migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" doctrine:migrations:migrate --no-interaction
    if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

    Write-Host "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear
    if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
}
