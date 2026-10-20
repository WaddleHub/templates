$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Fetch tags and check out the target version.
# Write-Host "[WADDLE] Updating Kanboard source."
# git -C "./website/src" fetch --tags
# if ($LASTEXITCODE -ne 0) { throw "Failed to fetch tags." }
# git -C "./website/src" checkout {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to checkout new version." }

# Preserve the config.php across the checkout.
Write-Host "[WADDLE] Re-applying configuration."
Copy-Item "./website/conf/kanboard/config.php" "./website/src/config.php"

# Run any pending database migrations.
Write-Host "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Clear cached assets.
Write-Host "[WADDLE] Clearing cache."
Remove-Item "./website/src/data/cache/*" -Recurse -Force -ErrorAction SilentlyContinue
