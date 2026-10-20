#!/bin/sh -eu
# Re-point the application URL after a local URL change, or a deploy/push to a remote environment.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# The application .env is copied verbatim from the local environment during a push (so the
# remote shares the same APP_SECRET / APP_KEY). Its APP_URL therefore still holds the local
# domain. Here we rewrite APP_URL to the domain configured for the target environment and clear
# the Symfony cache.

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

if [ ! -f "$ENV_FILE" ]; then
    echo "[WADDLE ERROR] $ENV_FILE not found." >&2
    exit 1
fi

{{#if ssl.enabled}}
SCHEME="https"
{{else}}
SCHEME="http"
{{/if}}

# Rewrite APP_URL, to account for URL changes made in the project.
sed "s#^APP_URL=.*#APP_URL=${SCHEME}://${TARGET_DOMAIN}#" "$ENV_FILE" > "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "$ENV_FILE"

# Clear the Symfony cache so the new APP_URL takes effect.
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear --env=prod

echo "[WADDLE] APP_URL updated to ${SCHEME}://${TARGET_DOMAIN} for $ENV environment."
