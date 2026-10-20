#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installer."

# Update WP CLI.
echo "[WADDLE] Downloading WP CLI."
if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar)" != "200" ]; then
    echo "[WADDLE ERROR] Failed to find WP CLI download."
    exit 1
fi

if [ -f "./bin/wp" ]; then
    rm -f "./bin/wp"
fi

curl -L --retry 3 --retry-delay 5 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    -o "./bin/wp"
chmod +x "./bin/wp"

if [ -n "$(ls -A "./website/src" 2>/dev/null)" ]; then
    # Backup website source.
    if [ "${WADDLE_BACKUP_SRC}" = "0" ]; then
        ./bin/web/backup
    fi

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/unix/${WADDLE_PLATFORM}/upgrade.sh
else
    # Install website.
    . ./website/script/unix/${WADDLE_PLATFORM}/install.sh
fi
