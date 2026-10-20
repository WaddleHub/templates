#!/bin/sh -eu
# Manage maintenance mode (PrestaShop PS_SHOP_ENABLE flag).
# Usage: maintenance.sh <is-active|enable|disable>
#
# PrestaShop has no portable CLI toggle for maintenance, so the PS_SHOP_ENABLE configuration
# value is set directly in the database. PS_SHOP_ENABLE=0 means the shop front office is closed
# (maintenance active); 1 means open.

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

# Maintenance runs outside the main build flow (which sources bin/deploy/set-env) — locally or on a
# remote over SSH. Load the project's gitignored .env so WADDLE_DB_USER / WADDLE_DB_PASSWORD (written
# by Waddle) are available.
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

ACTION="${1:-}"

# Run one SQL statement, printing result rows without column headers.
runSql() {
    docker compose exec -T db mysql -N \
        -u "${WADDLE_DB_USER}" \
        -p"${WADDLE_DB_PASSWORD}" \
        -e "$1" \
        "{{public.website.db_name}}"
}

case "$ACTION" in
    is-active)
        # Captured on its own (not piped), so a failing query stops the script rather than being
        # reported as "inactive".
        VALUE="$(runSql "SELECT value FROM ps_configuration WHERE name='PS_SHOP_ENABLE';")"
        case "$(printf '%s' "$VALUE" | tr -d '[:space:]')" in
            0) echo "active" ;;
            1) echo "inactive" ;;
            *)
                echo "[WADDLE ERROR] Unexpected PS_SHOP_ENABLE value: $VALUE" >&2
                exit 1
                ;;
        esac
        ;;
    enable)
        runSql "UPDATE ps_configuration SET value='0' WHERE name='PS_SHOP_ENABLE';"
        echo "enabled"
        ;;
    disable)
        runSql "UPDATE ps_configuration SET value='1' WHERE name='PS_SHOP_ENABLE';"
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
