$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

Write-Host "[WADDLE] Upgrading Directus."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-exact "directus@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Directus." }

# The node service bootstraps Directus before starting it, which migrates the database to the
# new release.
Write-Host "[WADDLE] Restarting Directus."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Directus." }
