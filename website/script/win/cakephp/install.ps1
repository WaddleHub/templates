$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

Write-Host "[WADDLE] Downloading CakePHP."
docker compose exec -T php composer create-project --prefer-dist cakephp/app `
    "{{project_path 'website/src'}}" "{{tags.website.version.major}}.{{tags.website.version.minor}}.*" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download CakePHP." }

# Replace the skeleton's config/app_local.php (placeholder database credentials and mail transport)
# with Waddle's rendered one.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/cakephp/app_local.php'}}" "{{project_path 'website/src'}}/config/app_local.php"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
