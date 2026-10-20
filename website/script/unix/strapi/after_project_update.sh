#!/bin/sh -eu
# Re-point the public URL after a local URL change, or a deploy/push to a remote environment, and
# on a remote build the website.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# The application .env is copied verbatim from the local environment during a push (so the
# remote shares the same secrets, which the synced database relies on). Its PUBLIC_URL therefore
# still holds the local domain. Here we rewrite PUBLIC_URL to the domain configured for the target
# environment, build the website on a remote, and restart Strapi, which only reads .env on start.

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

if [ ! -f "$ENV_FILE" ]; then
    echo "[WADDLE ERROR] $ENV_FILE not found." >&2
    exit 1
fi

{{#if ssl.enabled}}
SCHEME="https"
{{else}}
SCHEME="http"
{{/if}}

if [ -n "$TARGET_DOMAIN" ]; then
    # Rewrite PUBLIC_URL, to account for URL changes made in the project.
    sed "s#^PUBLIC_URL=.*#PUBLIC_URL=${SCHEME}://${TARGET_DOMAIN}#" "$ENV_FILE" > "${ENV_FILE}.tmp"
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
    echo "[WADDLE] PUBLIC_URL updated to ${SCHEME}://${TARGET_DOMAIN} for $ENV environment."
else
    echo "[WADDLE] No domain configured for $ENV environment, skipping URL update."
fi

# On a remote, install the dependencies and build the website from the code just pushed, with its
# PUBLIC_URL. A failed build fails the push, and the website already running keeps running.
if [ "$ENV" != "Local" ]; then
    docker compose run --rm --no-deps -T --entrypoint sh node "{{project_path 'node/script/build.sh'}}"
fi

docker compose restart node
