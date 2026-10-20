$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

# The source was restored without its node_modules (left out of the backup), and the database
# with it. Reinstall the dependencies the restored lock file names, then restart Strapi on them.
if (Test-Path "./website/src/package.json" -PathType Leaf) {
    Write-Host "[WADDLE] Reinstalling dependencies."
    docker compose exec -T -w "{{project_path 'website/src'}}" node npm ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw "Failed to reinstall dependencies." }

    Write-Host "[WADDLE] Restarting Strapi."
    docker compose restart node
    if ($LASTEXITCODE -ne 0) { throw "Failed to restart Strapi." }
}
