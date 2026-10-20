$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Directus has no project scaffold: a Directus project is a package.json depending on the
# `directus` package, plus its .env.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node mkdir -p "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to create the website source directory." }
docker compose exec -T node cp "{{project_path 'website/conf/directus/package.json'}}" "{{project_path 'website/src'}}/package.json"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/directus/src.gitignore'}}" "{{project_path 'website/src'}}/.gitignore"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/directus/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Install Directus.
Write-Host "[WADDLE] Installing Directus."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-exact "directus@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install Directus." }

# Install the database schema and create the admin account (from ADMIN_EMAIL/ADMIN_PASSWORD),
# the project name and owner. Passed as environment variables, so the admin password stays
# out of the .env.
Write-Host "[WADDLE] Installing the database and creating the admin user."
docker compose exec -T -w "{{project_path 'website/src'}}" `
    -e "ADMIN_EMAIL={{public.website.admin_email}}" `
    -e "ADMIN_PASSWORD=${env:WADDLE_ADMIN_PASSWORD}" `
    -e "PROJECT_OWNER={{public.website.admin_email}}" `
{{#if public.website.title}}
    -e "PROJECT_NAME={{public.website.title}}" `
{{/if}}
    node npx directus bootstrap
if ($LASTEXITCODE -ne 0) { throw "Failed to install the Directus database." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Directus."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Directus." }

# Wait for Directus to answer its ping endpoint, so the build only finishes once the site is up.
$healthCheck = "fetch('http://127.0.0.1:8055/server/ping').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Directus..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Directus failed to start. See: docker compose logs node"
}
