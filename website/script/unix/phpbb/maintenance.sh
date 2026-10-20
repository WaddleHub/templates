#!/bin/sh -eu
# Manage maintenance mode (phpBB board disable via phpbbcli).
# Usage: maintenance.sh <is-active|enable|disable>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ACTION="${1:-}"
CLI="{{project_path 'website/src'}}/phpBB/bin/phpbbcli.php"

case "$ACTION" in
    is-active)
        # Captured on its own (not piped), so a failing query stops the script rather than being
        # reported as "inactive".
        VALUE="$(docker compose exec -T php php "$CLI" config:get board_disable)"
        case "$(printf '%s' "$VALUE" | tr -d '[:space:]')" in
            1) echo "active" ;;
            0) echo "inactive" ;;
            *)
                echo "[WADDLE ERROR] Unexpected board_disable value: $VALUE" >&2
                exit 1
                ;;
        esac
        ;;
    enable)
        docker compose exec -T php php "$CLI" config:set board_disable 1
        echo "enabled"
        ;;
    disable)
        docker compose exec -T php php "$CLI" config:set board_disable 0
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
