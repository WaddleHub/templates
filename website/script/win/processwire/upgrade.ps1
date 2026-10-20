$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# Pull the latest changes for the target version. ProcessWire automatically
# applies any pending database upgrades on the next boot after the core files
# are updated.
# Write-Host "[WADDLE] Updating ProcessWire core."
# git -C "./website/src" fetch --tags
# if ($LASTEXITCODE -ne 0) { throw "Failed to fetch tags." }
# git -C "./website/src" checkout {{tags.website.version.full_raw}}
# if ($LASTEXITCODE -ne 0) { throw "Failed to checkout new version." }

# Clear ProcessWire's cache to pick up the new version.
Write-Host "[WADDLE] Clearing cache."
Remove-Item "./website/src/site/assets/cache/*" -Recurse -Force -ErrorAction SilentlyContinue
