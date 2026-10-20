#!/bin/sh -eu
# Correct the board URL in the phpBB database after a database sync.
# Usage: after_db_updated.sh <Local|Production|Stage|Dev>
#
# phpBB stores the canonical host, protocol and cookie domain in the phpbb_config table
# (server_name, server_protocol, cookie_domain). After importing a database from another
# environment those values point at the wrong domain, so we rewrite them for the target
# environment and purge the cache.

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
        TARGET_DOMAIN="{{public.website.url}}"
        ;;
    Production)
        TARGET_DOMAIN="{{public.remotes.production.domain}}"
        ;;
    Stage)
        TARGET_DOMAIN="{{public.remotes.stage.domain}}"
        ;;
    Dev)
        TARGET_DOMAIN="{{public.remotes.dev.domain}}"
        ;;
    *)
        echo "Usage: $0 <Local|Production|Stage|Dev>" >&2
        exit 1
        ;;
esac

if [ -z "$TARGET_DOMAIN" ]; then
    echo "[WADDLE] No domain configured for $ENV environment, skipping URL update."
    exit 0
fi

{{#if ssl.enabled}}
SCHEME="https"
COOKIE_SECURE="1"
{{else}}
SCHEME="http"
COOKIE_SECURE="0"
{{/if}}

printf '%s\n' \
    "UPDATE phpbb_config SET config_value='${TARGET_DOMAIN}' WHERE config_name='server_name';" \
    "UPDATE phpbb_config SET config_value='${TARGET_DOMAIN}' WHERE config_name='cookie_domain';" \
    "UPDATE phpbb_config SET config_value='${SCHEME}://' WHERE config_name='server_protocol';" \
    "UPDATE phpbb_config SET config_value='${COOKIE_SECURE}' WHERE config_name='cookie_secure';" \
| docker compose exec -i db mysql \
    -u "${WADDLE_DB_USER}" \
    -p"${WADDLE_DB_PASSWORD}" \
    "{{public.website.db_name}}"

# Purge the phpBB cache so the new configuration is reloaded.
docker compose exec -T php php "{{project_path 'website/src'}}/phpBB/bin/phpbbcli.php" cache:purge

echo "[WADDLE] Board URL updated to ${SCHEME}://${TARGET_DOMAIN} for $ENV environment."
