$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Fetch and checkout the new version tag.
# Write-Host "[WADDLE] Fetching new version."
# git -C "./website/src/w" fetch --depth=1 origin {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to fetch new version." }
# git -C "./website/src/w" checkout {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to checkout new version." }

# Update the default skin to the commit pinned by the new version.
# Write-Host "[WADDLE] Updating default skin."
# git -C "./website/src/w" submodule update --init --depth=1 -- skins/Vector
# if ($LASTEXITCODE -ne 0) { throw "Failed to update default skin." }

# Update PHP dependencies.
Write-Host "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev --working-dir="{{project_path 'website/src'}}/w"
if ($LASTEXITCODE -ne 0) { throw "Failed to update dependencies." }

# Run database updates.
Write-Host "[WADDLE] Running database updates."
docker compose exec -T php php "{{project_path 'website/src'}}/w/maintenance/update.php" --quick
if ($LASTEXITCODE -ne 0) { throw "Failed to run database updates." }
