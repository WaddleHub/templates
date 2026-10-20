$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website rollback."

# Clear cache after restore to avoid serving stale compiled templates.
if (Test-Path "./website/src/phpBB" -PathType Container) {
    Write-Host "[WADDLE] Clearing cache."
    docker compose exec -T php php "{{project_path 'website/src'}}/phpBB/bin/phpbbcli.php" cache:purge
    if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
}
