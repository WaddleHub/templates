#!/bin/sh -eu
# Re-point the wiki server URL after a local URL change, or a deploy/push to a remote environment.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# MediaWiki stores its canonical server URL in website/src/w/LocalSettings.php ($wgServer). That
# file is committed with the local domain, so after a push to a remote we rewrite it to the
# target environment's domain.

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"
CONFIG_FILE="website/src/w/LocalSettings.php"

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

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[WADDLE ERROR] $CONFIG_FILE not found." >&2
    exit 1
fi

{{#if ssl.enabled}}
SCHEME="https"
{{else}}
SCHEME="http"
{{/if}}

# Rewrite $wgServer, to account for URL changes made in the project.
sed "s#^\$wgServer = .*#\$wgServer = \"${SCHEME}://${TARGET_DOMAIN}\";#" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo "[WADDLE] \$wgServer updated to ${SCHEME}://${TARGET_DOMAIN} for $ENV environment."
