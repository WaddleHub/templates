$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

$phpbbSrcContainer = "{{project_path 'website/src'}}/phpBB"

# Fetch tags and check out the target version.
# Write-Host "[WADDLE] Updating phpBB source."
# git -C "./website/src" fetch --tags
# if ($LASTEXITCODE -ne 0) { throw "Failed to fetch tags." }
# git -C "./website/src" checkout {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to checkout new version." }

# Update PHP dependencies.
Write-Host "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev `
    --working-dir="$phpbbSrcContainer"
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }

# Run database migrations.
Write-Host "[WADDLE] Running database migrations."
docker compose exec -T php php "$phpbbSrcContainer/bin/phpbbcli.php" db:migrate `
    --safe-mode
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }

# Clear compiled templates and cache.
Write-Host "[WADDLE] Clearing cache."
docker compose exec -T php php "$phpbbSrcContainer/bin/phpbbcli.php" cache:purge
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
