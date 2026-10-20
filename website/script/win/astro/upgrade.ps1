$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Update dependencies, with Astro at the pinned version, and the Node adapter at its newest version
# supporting it.
Write-Host "[WADDLE] Upgrading Astro."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm update --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "astro@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Astro." }
$adapterVersion = docker compose exec -T -w "{{project_path 'website/src'}}" node `
    node "{{project_path 'website/conf/astro/adapter-version.cjs'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to find a Node adapter version supporting Astro." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@astrojs/node@$($adapterVersion.Trim())"
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade the Node adapter." }

# Regenerate the website's types for the new release & restart.
Write-Host "[WADDLE] Syncing Astro's generated types."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx astro sync
if ($LASTEXITCODE -ne 0) { throw "Failed to sync Astro's generated types." }

Write-Host "[WADDLE] Restarting Astro."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Astro." }
