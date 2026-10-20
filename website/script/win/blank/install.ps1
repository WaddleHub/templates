$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if (-not (Test-Path ./website/src -PathType Container)) {
    New-Item -ItemType Directory -Path ./website/src -Force | Out-Null
}
