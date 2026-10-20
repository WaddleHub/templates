$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website upgrade."

# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
docker compose exec -T php "{{project_path 'bin'}}/wp" core update `
    --path="{{project_path 'website/src'}}" --version={{tags.website.version.full_raw}} --allow-root
if ($LASTEXITCODE -ne 0) { throw "Failed to update WordPress core." }
docker compose exec -T php "{{project_path 'bin'}}/wp" core update-db `
    --path="{{project_path 'website/src'}}" --allow-root
if ($LASTEXITCODE -ne 0) { throw "Failed to update the database." }
