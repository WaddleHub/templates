$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Nest at the pinned version (its packages are released together).
Write-Host "[WADDLE] Upgrading Nest."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@nestjs/common@{{tags.website.version.raw}}" `
    "@nestjs/core@{{tags.website.version.raw}}" `
    "@nestjs/platform-express@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Nest." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-dev "@nestjs/testing@{{tags.website.version.raw}}" `
    "@nestjs/cli@{{tags.website.version.major}}" "@nestjs/schematics@{{tags.website.version.major}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Nest's dev tools." }

Write-Host "[WADDLE] Restarting Nest."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Nest." }
