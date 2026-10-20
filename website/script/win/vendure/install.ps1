$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Vendure's own scaffolder (@vendure/create) at the pinned version. Its
# prompt-free mode (`--ci`) only offers SQLite or PostgreSQL, so it creates the project with
# SQLite, which is switched to MariaDB below. It also builds and fills a SQLite database, which is
# removed again.
Write-Host "[WADDLE] Scaffolding the Vendure project."
docker compose exec -T -w "{{project_path 'website'}}" node `
    npx --yes "@vendure/create@{{tags.website.version.raw}}" src --ci --use-npm --log-level info
if ($LASTEXITCODE -ne 0) { throw "Failed to scaffold the Vendure project." }

# Name the website's package after the project, then switch to MariaDB. Remove the SQLite
# database, its migration, the sample product images it imported and its driver then and add
# th MariaDB driver.
Write-Host "[WADDLE] Switching the database to MariaDB."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to name the website package." }
docker compose exec -T -w "{{project_path 'website/src'}}" node sh -c `
    'rm -f vendure.sqlite src/migrations/*.ts && rm -rf static/assets/source/* static/assets/preview/* static/assets/cache/*'
if ($LASTEXITCODE -ne 0) { throw "Failed to remove the SQLite database." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm uninstall --no-audit --no-fund `
    better-sqlite3
if ($LASTEXITCODE -ne 0) { throw "Failed to remove the SQLite driver." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-exact mysql2
if ($LASTEXITCODE -ne 0) { throw "Failed to install the MariaDB driver." }

# Apply configuration: the .env, and the vendure-config.ts (with its environment.d.ts) and
# vite.config.mts reading it.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/vendure/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/vendure/vendure-config.ts'}}" "{{project_path 'website/src'}}/src/vendure-config.ts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/vendure/environment.d.ts'}}" "{{project_path 'website/src'}}/src/environment.d.ts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/vendure/vite.config.mts'}}" "{{project_path 'website/src'}}/vite.config.mts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Create the database schema and the shop's initial data (and sample products), from the data
# files that come with @vendure/create.
Write-Host "[WADDLE] Installing the database."
docker compose exec -T -w /tmp node npm pack --silent "@vendure/create@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to download Vendure's initial data." }
docker compose exec -T -w /tmp node sh -c `
    'rm -rf /tmp/vendure-create && mkdir /tmp/vendure-create && tar -xzf vendure-create-*.tgz -C /tmp/vendure-create && rm vendure-create-*.tgz'
if ($LASTEXITCODE -ne 0) { throw "Failed to extract Vendure's initial data." }
docker compose exec -T -w "{{project_path 'website/src'}}" node `
    node "{{project_path 'website/conf/vendure/setup.cjs'}}" /tmp/vendure-create/package/assets `
    {{#if public.website.deploy_sample_data}}true{{else}}false{{/if}}
if ($LASTEXITCODE -ne 0) { throw "Failed to install the database." }
docker compose exec -T node rm -rf /tmp/vendure-create
if ($LASTEXITCODE -ne 0) { throw "Failed to remove Vendure's initial data." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Vendure."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Vendure." }

# Wait for Vendure to answer its health check, so the build only finishes once the site is up.
$healthCheck = "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Vendure..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Vendure failed to start. See: docker compose logs node"
}
