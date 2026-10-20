$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Strapi's own upgrade tool updates every @strapi package to the target release and runs its
# codemods. Strapi migrates the database when it starts on the new release, after the restart below.
Write-Host "[WADDLE] Upgrading Strapi."
docker compose exec -T -w "{{project_path 'website/src'}}" node `
    npx --yes @strapi/upgrade to "{{tags.website.version.raw}}" --yes
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade Strapi." }

Write-Host "[WADDLE] Updating the email provider."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@strapi/provider-email-nodemailer@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update the email provider." }

Write-Host "[WADDLE] Restarting Strapi."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Strapi." }
