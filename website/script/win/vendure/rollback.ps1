$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

# Re-install dependencies and restart.
if (Test-Path "./website/src/package.json" -PathType Leaf) {
    Write-Host "[WADDLE] Reinstalling dependencies."
    docker compose exec -T -w "{{project_path 'website/src'}}" node npm ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw "Failed to reinstall dependencies." }

    Write-Host "[WADDLE] Restarting Vendure."
    docker compose restart node
    if ($LASTEXITCODE -ne 0) { throw "Failed to restart Vendure." }
}
