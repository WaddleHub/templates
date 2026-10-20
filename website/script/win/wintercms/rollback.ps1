$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

if (Test-Path "./website/src/artisan" -PathType Leaf) {
    Write-Host "[WADDLE] Running migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" migrate
    if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

    Write-Host "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" cache:clear
    if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

    Write-Host "[WADDLE] Disabling maintenance mode."
    docker compose exec -T php php "{{project_path 'website/src'}}/artisan" up
    if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
}
