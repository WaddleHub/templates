#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

if [ -f "./website/src/bin/magento" ]; then
    echo "[WADDLE] Running migrations."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:upgrade

    echo "[WADDLE] Compiling DI."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:di:compile

    echo "[WADDLE] Refreshing indexes."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" indexer:reindex

    echo "[WADDLE] Refreshing caches."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" cache:flush

    echo "[WADDLE] Disabling maintenance mode."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:disable
fi
