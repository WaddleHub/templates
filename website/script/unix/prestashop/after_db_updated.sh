#!/bin/sh -eu
# Correct base URLs in the PrestaShop database after a database sync.
# Usage: after_db_updated.sh <Local|Production|Stage|Dev>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

# This script can run outside the main build flow (which sources bin/deploy/set-env) — e.g. after a
# database sync, or on a remote over SSH. Load the project's gitignored .env so WADDLE_DB_USER /
# WADDLE_DB_PASSWORD (written by Waddle) are available.
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

ENV="${1:-}"

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

if [ -z "$TARGET_URL" ]; then
    echo "[WADDLE] No domain configured for $ENV environment, skipping URL update."
    exit 0
fi

printf '%s\n' \
    "UPDATE ps_shop_url SET domain='${TARGET_URL}', domain_ssl='${TARGET_URL}' WHERE id_shop=1;" \
    "UPDATE ps_configuration SET value='${TARGET_URL}' WHERE name='PS_SHOP_DOMAIN';" \
    "UPDATE ps_configuration SET value='${TARGET_URL}' WHERE name='PS_SHOP_DOMAIN_SSL';" \
| docker compose exec -i db mysql \
    -u "${WADDLE_DB_USER}" \
    -p"${WADDLE_DB_PASSWORD}" \
    "{{public.website.db_name}}"

echo "[WADDLE] URL replacement complete for $ENV environment."
