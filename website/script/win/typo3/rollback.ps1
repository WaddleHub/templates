$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

# Re-run database schema updates against the restored version.
if (Test-Path "./website/src/vendor/bin/typo3" -PathType Leaf) {
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" database:updateschema
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" maintenance:disable
}
