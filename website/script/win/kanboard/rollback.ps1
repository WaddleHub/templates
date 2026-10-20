$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website rollback."

# Re-apply configuration after restore.
if (Test-Path "./website/conf/kanboard/config.php" -PathType Leaf) {
    Write-Host "[WADDLE] Re-applying configuration."
    Copy-Item "./website/conf/kanboard/config.php" "./website/src/config.php"
}

# Run migrations to ensure schema is consistent with restored source.
if (Test-Path "./website/src" -PathType Container) {
    Write-Host "[WADDLE] Running database migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate
    if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

    # Clear cache after restore.
    Write-Host "[WADDLE] Clearing cache."
    Remove-Item "./website/src/data/cache/*" -Recurse -Force -ErrorAction SilentlyContinue
}
