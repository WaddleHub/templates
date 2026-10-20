#!/bin/sh -eu
# Manage maintenance mode (Flarum's offline mode).
# Usage: maintenance.sh <is-active|enable|disable>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ACTION="${1:-}"
CONFIG="{{project_path 'website/src'}}/config.php"

# Set the 'offline' key in config.php
set_offline() {
    docker compose exec -T php php -r '
        $file = $argv[1];
        $config = require $file;
        $config["offline"] = $argv[2] === "true";
        file_put_contents($file, "<?php return " . var_export($config, true) . ";\n");
    ' "$CONFIG" "$1"
}

case "$ACTION" in
    is-active)
        # Captured on its own (not piped), so a failure stops the script rather than being
        # reported as "inactive".
        VALUE="$(docker compose exec -T php php -r '
            $config = require $argv[1];
            echo empty($config["offline"]) ? "inactive" : "active";
        ' "$CONFIG")"
        echo "$VALUE"
        ;;
    enable)
        set_offline true
        echo "enabled"
        ;;
    disable)
        set_offline false
        echo "disabled"
        ;;
    *)
        echo "Usage: $0 <is-active|enable|disable>" >&2
        exit 1
        ;;
esac
