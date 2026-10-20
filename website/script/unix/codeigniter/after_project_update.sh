#!/bin/sh -eu
# Re-point CodeIgniter's base URL after a local URL change, or a deploy/push to a remote environment.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# website/src/.env is copied verbatim from the local environment during a push, so its app.baseURL
# still holds the local domain. Here we rewrite it to the domain configured for the target
# environment.

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"
ENV_FILE="website/src/.env"

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
{{else}}
SCHEME="http"
{{/if}}

BASE_URL="app.baseURL = '${SCHEME}://${TARGET_DOMAIN}/'"

if [ -f "$ENV_FILE" ] && grep -q "^app\.baseURL" "$ENV_FILE"; then
    sed "s#^app\.baseURL.*#${BASE_URL}#" "$ENV_FILE" > "${ENV_FILE}.tmp"
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
else
    echo "$BASE_URL" >> "$ENV_FILE"
fi

echo "[WADDLE] app.baseURL updated to ${SCHEME}://${TARGET_DOMAIN}/ for $ENV environment."
