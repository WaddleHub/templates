#!/bin/sh -eu
# Manage WordPress maintenance mode.
# Usage: maintenance.sh <is-active|enable|disable>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ACTION="${1:-}"
WP_PATH="{{project_path 'website/src'}}"

case "$ACTION" in
    is-active)
        if [ -f "website/src/.maintenance" ]; then
            echo "active"
        else
            echo "inactive"
        fi
        ;;
    enable)
        docker compose exec -T php "{{project_path 'bin'}}/wp" maintenance-mode activate --allow-root \
            --path="$WP_PATH"
        echo "enabled"
        ;;
    disable)
        docker compose exec -T php "{{project_path 'bin'}}/wp" maintenance-mode deactivate --allow-root \
            --path="$WP_PATH"
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
