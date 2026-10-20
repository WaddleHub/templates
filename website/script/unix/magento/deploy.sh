#!/bin/sh -eu
# Magento deployment steps, shared by the after_project_update.sh and after_db_updated.sh hooks.

MAGENTO_DEPLOY_BIN="{{project_path 'website/src'}}/bin/magento"

# Run bin/magento in the php container.
magento() {
    docker compose exec -T php "$MAGENTO_DEPLOY_BIN" "$@"
}

# Bring the site in line with its code and database.
#
# Local: apply schema and data patches, reindex and flush the cache. Local stays in developer mode.
# Remotes: the same under maintenance mode, plus production mode with compiled DI and deployed
# static content.
#
# Skipped when the database holds no Magento install because on a first deploy, the push runs its
# hook before the database is uploaded, against an empty database. The count is captured on its own,
# so an unreachable database stops the script instead of reading as an empty one.
#
# Usage: magento_deploy <Local|Production|Stage|Dev>
magento_deploy() {
    TABLE_COUNT="$(docker compose exec -u 0 -T db mariadb -N -e \
        "SELECT COUNT(*) FROM information_schema.tables \
        WHERE table_schema = '{{public.website.db_name}}' AND table_name = 'core_config_data'")"

    if [ "$TABLE_COUNT" != "1" ]; then
        echo "[WADDLE NOTICE] No Magento database here yet. Deployment steps will run once the" \
            "database is uploaded."
        return 0
    fi

    if [ "$1" = "Local" ]; then
        echo "[WADDLE] Applying schema and data patches."
        magento setup:upgrade
        magento_reindex
        magento cache:flush
        return 0
    fi

    echo "[WADDLE] Deploying Magento in production mode. This can take several minutes."
    magento maintenance:enable

    # A failure from here on leaves maintenance mode on. There's no safe automatic rollback on a
    # remote, so the site stays closed until the user has restored their backup.
    trap 'echo "[WADDLE ERROR] Deployment failed. The site stays in maintenance mode: restore your" \
        "backup, then switch maintenance mode off." >&2' EXIT

    # setup:upgrade clears generated code and static files, so it runs before they're rebuilt.
    echo "[WADDLE] Applying schema and data patches."
    magento setup:upgrade
    magento deploy:mode:set production --skip-compilation

    echo "[WADDLE] Compiling DI."
    magento setup:di:compile

    echo "[WADDLE] Deploying static content."
    magento setup:static-content:deploy en_US{{#unless (is_equal public.website.language 'en_US')}} "{{public.website.language}}"{{/unless}}

    magento_reindex
    magento cache:flush

    trap - EXIT
    magento maintenance:disable
}

# Reindex. A failed index doesn't take the site down, so it's reported rather than fatal.
magento_reindex() {
    echo "[WADDLE] Refreshing indexes."
    magento indexer:reindex \
        || echo "[WADDLE WARNING] One or more indexes failed to reindex. You may need to reindex manually."
}
