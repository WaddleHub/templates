#!/bin/sh -eu
# Re-point the site base URL after a local URL change, or a deploy/push to a remote environment.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# TYPO3 stores each site's base URL in website/src/config/sites/<identifier>/config.yaml (base:).
# Those files are committed with the local domain, so after a push to a remote we rewrite the
# base of every configured site to the target environment's domain and flush the cache.

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

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
{{else}}
SCHEME="http"
{{/if}}

# Rewrite the base of every configured site, to account for URL changes made in the project.
updated=0

for cfg in website/src/config/sites/*/config.yaml; do
    [ -f "$cfg" ] || continue
    sed "s#^base:.*#base: '${SCHEME}://${TARGET_DOMAIN}/'#" "$cfg" > "${cfg}.tmp"
    mv "${cfg}.tmp" "$cfg"
    updated=1
done

if [ "$updated" = "0" ]; then
    echo "[WADDLE ERROR] No site configuration found in website/src/config/sites." >&2
    exit 1
fi

# Flush TYPO3 caches so the new base URL takes effect.
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush

echo "[WADDLE] Site base URL updated to ${SCHEME}://${TARGET_DOMAIN}/ for $ENV environment."
