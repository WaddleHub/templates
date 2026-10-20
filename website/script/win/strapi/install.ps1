$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Scaffold the project.
#
# Arguments go straight to docker rather than through `sh -c`, since PowerShell mangles the double
# quotes such a script would need.
Write-Host "[WADDLE] Creating Strapi project."
docker compose exec -T node npx --yes "create-strapi@{{tags.website.version.raw}}" `
    "{{project_path 'website/src'}}" `
    --typescript --use-npm --install --no-git-init --no-example --skip-cloud --no-run `
    --no-enable-ab-tests `
{{#if public.mariadb.install}}
    --dbclient mysql --dbhost db --dbport 3306 --dbname "{{public.website.db_name}}" `
    --dbusername "$env:WADDLE_DB_USER" --dbpassword "$env:WADDLE_DB_PASSWORD"
{{else}}
    --dbclient sqlite
{{/if}}
if ($LASTEXITCODE -ne 0) { throw "Failed to create the Strapi project." }

# Apply configuration .env (persistent secrets, database, mail), and Strapi's server and
# plugin configs with additions (public URL behind nginx, SMTP mail provider).
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/strapi/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/strapi/config/server.ts'}}" "{{project_path 'website/src'}}/config/server.ts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/strapi/config/plugins.ts'}}" "{{project_path 'website/src'}}/config/plugins.ts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# The SMTP mail provider config/plugins.ts uses when mail is on, pinned to the Strapi release.
Write-Host "[WADDLE] Installing the email provider."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@strapi/provider-email-nodemailer@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install the email provider." }

# Create the admin account. Loading Strapi for this also creates the database schema.
Write-Host "[WADDLE] Creating admin user."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx strapi admin:create-user `
    --email "{{public.website.admin_email}}" `
    --password "$env:WADDLE_ADMIN_PASSWORD" `
    --firstname "{{public.website.admin_firstname}}"{{#if public.website.admin_lastname}} `
    --lastname "{{public.website.admin_lastname}}"{{/if}}
if ($LASTEXITCODE -ne 0) { throw "Failed to create the admin user." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Strapi."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Strapi." }

# Wait for Strapi to answer its health endpoint, so the build only finishes once the site is up.
# The first start in development mode compiles the TypeScript and prepares the admin panel.
$healthCheck = "fetch('http://127.0.0.1:1337/_health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Strapi..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Strapi failed to start. See: docker compose logs node"
}
