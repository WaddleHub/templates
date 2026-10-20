$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

if (Test-Path "./website/src/flarum" -PathType Leaf) {
    # Re-run migrations against the restored database to ensure the schema matches
    # the rolled-back code version. Flarum's migrate is idempotent — safe if the
    # DB restore already left it in sync.
    Write-Host "[WADDLE] Running database migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" migrate
    if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

    Write-Host "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" cache:clear
    if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }

    Write-Host "[WADDLE] Taking site out of maintenance mode."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" up
    if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
}
