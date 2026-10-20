#!/bin/sh -eu
# Manage maintenance mode (Laravel artisan down/up).
# Usage: maintenance.sh <is-active|enable|disable>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ACTION="${1:-}"
ARTISAN="{{project_path 'website/src'}}/artisan"

case "$ACTION" in
    is-active)
        # Laravel marks maintenance with storage/framework/down (8+) or maintenance.php (older).
        if [ -f "website/src/storage/framework/down" ] \
            || [ -f "website/src/storage/framework/maintenance.php" ]; then
            echo "active"
        else
            echo "inactive"
        fi
        ;;
    enable)
        docker compose exec -T php php "$ARTISAN" down
        echo "enabled"
        ;;
    disable)
        docker compose exec -T php php "$ARTISAN" up
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
