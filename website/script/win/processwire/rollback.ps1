$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

# Clear ProcessWire's cache after restoring.
if (Test-Path "./website/src/site/assets/cache" -PathType Container) {
    Write-Host "[WADDLE] Clearing cache."
    Remove-Item "./website/src/site/assets/cache/*" -Recurse -Force -ErrorAction SilentlyContinue
}
