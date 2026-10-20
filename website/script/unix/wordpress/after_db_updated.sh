#!/bin/sh -eu
# Correct base URLs in the WordPress database after a database sync, or a local URL change.
# Usage: after_db_updated.sh <Local|Production|Stage|Dev>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"
WP_PATH="{{project_path 'website/src'}}"

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

# wp search-replace handles serialized data safely.
#
# --allow-root is acceptable and necessary since the intention
# is to run docker as rootless on remote servers and locally
# this flag has no impact either way.

# First replace the domain the database itself points at (its "home" option). It needn't be one
# this project still has configured: after a local URL change it's the previous URL, and after an
# import it can be a colleague's local URL or an environment's old domain. So it's read from the
# database at run time rather than baked in at render time. display_errors=stderr keeps PHP
# notices out of the captured value.
if ! DB_URL="$(docker compose exec -T php php -d display_errors=stderr "{{project_path 'bin'}}/wp" \
    option get home --path="$WP_PATH" --allow-root 2>/dev/null)"; then
    echo "[WADDLE ERROR] Couldn't read the site's home URL from the database." >&2
    exit 1
fi
DB_DOMAIN="${DB_URL#*://}"
DB_DOMAIN="${DB_DOMAIN%%/*}"

case "$DB_DOMAIN" in
    "" | *[!A-Za-z0-9.:-]*)
        echo "[WADDLE ERROR] The site's home URL in the database isn't a valid URL: $DB_URL" >&2
        exit 1
        ;;
    "$TARGET_URL")
        ;;
    *)
        docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace \
            "$DB_DOMAIN" "$TARGET_URL" --all-tables --path="$WP_PATH" --allow-root
        ;;
esac

# Then replace any remaining references to the other configured environments' domains.
{{#if (not_empty public.website.url)}}
if [ "$ENV" != "Local" ] && [ "$DB_DOMAIN" != "{{public.website.url}}" ]; then
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace \
        "{{public.website.url}}" "$TARGET_URL" --all-tables --path="$WP_PATH" --allow-root
fi
{{/if}}
{{#if (not_empty public.remotes.production.domain)}}
if [ "$ENV" != "Production" ] && [ "$DB_DOMAIN" != "{{public.remotes.production.domain}}" ]; then
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace \
        "{{public.remotes.production.domain}}" "$TARGET_URL" --all-tables --path="$WP_PATH" --allow-root
fi
{{/if}}
{{#if (not_empty public.remotes.stage.domain)}}
if [ "$ENV" != "Stage" ] && [ "$DB_DOMAIN" != "{{public.remotes.stage.domain}}" ]; then
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace \
        "{{public.remotes.stage.domain}}" "$TARGET_URL" --all-tables --path="$WP_PATH" --allow-root
fi
{{/if}}
{{#if (not_empty public.remotes.dev.domain)}}
if [ "$ENV" != "Dev" ] && [ "$DB_DOMAIN" != "{{public.remotes.dev.domain}}" ]; then
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace \
        "{{public.remotes.dev.domain}}" "$TARGET_URL" --all-tables --path="$WP_PATH" --allow-root
fi
{{/if}}

echo "[WADDLE] URL replacement complete for $ENV environment."
