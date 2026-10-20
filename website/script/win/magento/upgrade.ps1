$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Disable Composer's block-insecure audit to allow updating Magento's dev
# dependencies (e.g. phpunit) that carry security advisories unrelated to runtime.
docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer audit setting." }

Write-Host "[WADDLE] Updating packages."
docker compose exec -T php composer require-commerce `
    magento/product-community-edition {{tags.website.version.full_raw}} `
    --no-update -d "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }
docker compose exec -T php composer update --dev -d "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update packages." }

Write-Host "[WADDLE] Removing cache and log data."
Remove-Item "./website/src/var/cache/*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "./website/src/var/page_cache/*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "./website/src/generated/code/*" -Recurse -Force -ErrorAction SilentlyContinue

# Update sample data if present.
if (Test-Path "./website/src/sample-data" -PathType Container) {
    git -C "./website/src/sample-data" pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "Failed to update sample data." }
}
