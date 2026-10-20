$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Next.js and its ESLint config at the pinned version.
Write-Host "[WADDLE] Upgrading Next.js."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "next@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Next.js." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-dev "eslint-config-next@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Next.js's ESLint config." }

Write-Host "[WADDLE] Restarting Next.js."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Next.js." }
