$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

Write-Host "[WADDLE] Downloading Drupal."
docker compose exec -T php composer create-project drupal/recommended-project:"{{tags.website.version.major}}.{{tags.website.version.minor}}.*" `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Drupal." }
