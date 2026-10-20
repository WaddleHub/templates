#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installer."

if [ -n "$(ls -A "./website/src" 2>/dev/null)" ]; then
    if [ "${WADDLE_BACKUP_SRC}" = "0" ]; then
        ./bin/web/backup \
            --exclude "phpBB/files phpBB/store phpBB/cache"
    fi
    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/unix/${WADDLE_PLATFORM}/upgrade.sh
else
    . ./website/script/unix/${WADDLE_PLATFORM}/install.sh
fi
