$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if (-not (Test-Path ./website/src -PathType Container)) {
    New-Item -ItemType Directory -Path ./website/src -Force | Out-Null
}

docker compose exec -T php composer config -g audit.block-insecure false
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Composer audit setting." }

# --no-git: by default `symfony new` makes website/src a git repository of its own, which the
# project's repository would then only record as a gitlink, leaving clones with an empty
# website/src.
docker compose exec -T php symfony new --webapp --no-git --dir="{{project_path 'website/src'}}" `
    --version={{tags.website.version.major}}.{{tags.website.version.minor}}.*
if ($LASTEXITCODE -ne 0) { throw "Failed to download Symfony." }
