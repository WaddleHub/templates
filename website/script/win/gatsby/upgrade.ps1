$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies.
Write-Host "[WADDLE] Upgrading Gatsby."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "gatsby@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Gatsby." }

# Clear cache & restart.
Write-Host "[WADDLE] Clearing the Gatsby cache."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx gatsby clean
if ($LASTEXITCODE -ne 0) { throw "Failed to clear the Gatsby cache." }

Write-Host "[WADDLE] Restarting Gatsby."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Gatsby." }
