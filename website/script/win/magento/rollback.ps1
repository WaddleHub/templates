$ErrorActionPreference = "Stop"

Write-Host "[WADDLE] Starting website rollback."

if (Test-Path "./website/src/bin/magento" -PathType Leaf) {
    Write-Host "[WADDLE] Running migrations."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:upgrade

    Write-Host "[WADDLE] Compiling DI."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:di:compile

    Write-Host "[WADDLE] Refreshing indexes."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" indexer:reindex

    Write-Host "[WADDLE] Refreshing caches."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" cache:flush

    Write-Host "[WADDLE] Disabling maintenance mode."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:disable
}
