#!/bin/sh -eu
# Correct base URLs in the Magento database after a database sync or a local URL change, then run
# Magento's deployment steps (see deploy.sh), which also flush the cache.
# Usage: after_db_updated.sh <Local|Production|Stage|Dev>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"
BIN_MAGENTO="{{project_path 'website/src'}}/bin/magento"

case "$ENV" in
    Local)
        TARGET_URL="{{public.website.url}}"
        ;;
    Production)
        TARGET_URL="{{public.remotes.production.domain}}"
        ;;
    Stage)
        TARGET_URL="{{public.remotes.stage.domain}}"
        ;;
    Dev)
        TARGET_URL="{{public.remotes.dev.domain}}"
        ;;
    *)
        echo "Usage: $0 <Local|Production|Stage|Dev>" >&2
        exit 1
        ;;
esac

{{#if ssl.enabled}}
SCHEME="https"
{{else}}
SCHEME="http"
{{/if}}

if [ -z "$TARGET_URL" ]; then
    echo "[WADDLE] No domain configured for $ENV environment, skipping URL update."
else
    docker compose exec -T php "$BIN_MAGENTO" \
        config:set web/unsecure/base_url "${SCHEME}://${TARGET_URL}/"
    docker compose exec -T php "$BIN_MAGENTO" \
        config:set web/secure/base_url "https://${TARGET_URL}/"

    echo "[WADDLE] URL replacement complete for $ENV environment."
fi

. ./website/script/unix/magento/deploy.sh

magento_deploy "$ENV"
