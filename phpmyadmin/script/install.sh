#!/bin/sh -eux

PREFIX="{{project_path 'phpmyadmin/data/install'}}"

CONFIG_FILE="{{project_path 'phpmyadmin/conf/config.inc.custom.php'}}"

echo "[WADDLE NOTICE] Running PhpMyAdmin installation script."

# Create installation directory.
mkdir -p "$PREFIX"

# Create new project, if the installation directory is empty.
if [ -z "$(ls -A "$PREFIX" 2>/dev/null)" ]; then
    echo "[WADDLE NOTICE] Installing PhpMyAdmin from scratch."
    composer create-project phpmyadmin/phpmyadmin "$PREFIX" --no-interaction --no-dev
fi

# Setup config, if necessary.
if [ ! -f "$PREFIX/config.inc.php" ]; then
    echo "[WADDLE NOTICE] Setting up PhpMyAdmin config."
    cp -f "$PREFIX/config.sample.inc.php" "$PREFIX/config.inc.php"
    printf "\ninclude_once('%s');\n" "$CONFIG_FILE" >> "$PREFIX/config.inc.php"
fi
