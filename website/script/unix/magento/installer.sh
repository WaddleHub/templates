#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installer."

if [ -f "./website/src/bin/magento" ] \
    && [ -d "./mariadb/data/{{public.website.db_name}}" ] \
    && [ -n "$(find "./mariadb/data/{{public.website.db_name}}" -type f -name "*core_config_data*")" ]; then

    # Backup source code.
    if [ "${WADDLE_BACKUP_SRC}" = "0" ]; then
        ./bin/web/backup \
            --exclude "var/cache var/page_cache var/log generated pub/media sample-data"
    fi

    # Backup media data.
    if [ "${WADDLE_BACKUP_MEDIA}" = "0" ] && [ -d "./website/src/pub/media" ]; then
        echo "[WADDLE] Backing up media data."
        tar -C "./website/src" -czf "${WADDLE_BUILD_DIR}/media.tar.gz" pub/media
    fi

    # Enable maintenance mode.
    echo "[WADDLE NOTICE] Enabling Magento maintenance mode."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:enable || true

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/unix/${WADDLE_PLATFORM}/upgrade.sh
else
    # Install Magento.
    . ./website/script/unix/${WADDLE_PLATFORM}/install.sh
fi

{{#if public.redis.install}}
echo "[WADDLE] Configuring Redis cache."
yes | docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" \
    setup:config:set --cache-backend=redis --cache-backend-redis-server=redis
yes | docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" \
    setup:config:set --page-cache=redis --page-cache-redis-server=redis
yes | docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" \
    setup:config:set --session-save=redis --session-save-redis-host=redis
{{else}}
yes | docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" \
    setup:config:set --session-save=files
{{/if}}

# Set deployment mode. The installer only runs locally; remotes switch to production mode in the
# after_project_update.sh and after_db_updated.sh hooks (see deploy.sh).
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" deploy:mode:set developer

echo "[WADDLE] Running migrations."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" \
    setup:upgrade{{#if public.website.deploy_sample_data}} \
    || echo "[WADDLE ERROR] Please attempt freeing some disk space."{{/if}}

echo "[WADDLE] Compiling DI."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:di:compile

echo "[WADDLE] Refreshing indexes."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" indexer:reindex \
    || echo "[WADDLE WARNING] One or more indexes failed to reindex. You may need to reindex manually."

echo "[WADDLE] Refreshing caches."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" cache:flush

echo "[WADDLE] Disabling maintenance mode."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:disable
