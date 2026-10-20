#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website rollback."

# Re-apply configuration after restore.
if [ -f "./website/conf/kanboard/config.php" ]; then
    echo "[WADDLE] Re-applying configuration."
    cp "./website/conf/kanboard/config.php" "./website/src/config.php"
fi

# Run migrations to ensure schema is consistent with restored source.
if [ -d "./website/src" ]; then
    echo "[WADDLE] Running database migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate

    # Clear cache after restore.
    echo "[WADDLE] Clearing cache."
    rm -rf "./website/src/data/cache/"*
fi
