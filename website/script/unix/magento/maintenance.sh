#!/bin/sh -eu
# Manage Magento maintenance mode.
# Usage: maintenance.sh <is-active|enable|disable>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ACTION="${1:-}"
BIN_MAGENTO="{{project_path 'website/src'}}/bin/magento"

case "$ACTION" in
    is-active)
        if [ -f "website/src/var/.maintenance.flag" ]; then
            echo "active"
        else
            echo "inactive"
        fi
        ;;
    enable)
        docker compose exec -T php "$BIN_MAGENTO" maintenance:enable
        echo "enabled"
        ;;
    disable)
        docker compose exec -T php "$BIN_MAGENTO" maintenance:disable
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
