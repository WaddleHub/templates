#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installer."

if [ -n "$(ls -A "./website/src/web" 2>/dev/null)" ]; then
    # Backup source code before running upgrade.
    if [ "${WADDLE_BACKUP_SRC}" = "0" ]; then
        ./bin/web/backup
    fi
    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/unix/${WADDLE_PLATFORM}/upgrade.sh
else
    # Run installation script.
    . ./website/script/unix/${WADDLE_PLATFORM}/install.sh
fi

echo "[WADDLE NOTICE] Installing Drush"
{{#if (version_compare tags.website.version.raw '>=' '11.0.0')}}
docker compose exec -T php composer require drush/drush:"^13" \
    --working-dir="{{project_path 'website/src'}}" --no-interaction
{{else}}
{{#if (version_compare tags.website.version.raw '>=' '10.0.0')}}
docker compose exec -T php composer require drush/drush:"^12" \
    --working-dir="{{project_path 'website/src'}}" --no-interaction
{{else}}
docker compose exec -T php composer require drush/drush:"^11" \
    --working-dir="{{project_path 'website/src'}}" --no-interaction
{{/if}}
{{/if}}

# Run installer, if database is empty.
if [ -z "$(find "./mariadb/data/{{public.website.db_name}}" -maxdepth 1 -name '*.ibd' 2>/dev/null)" ]; then
    echo "[WADDLE NOTICE] Running installation routine."

    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/drush" si standard \
        --account-mail="{{public.website.admin_email}}" \
        --account-name="{{public.website.admin_username}}" \
        --account-pass="${WADDLE_ADMIN_PASSWORD}" \
        --db-url="mysql://${WADDLE_DB_USER}:${WADDLE_DB_PASSWORD}@db/{{public.website.db_name}}" \
        --yes --no-interaction \
        --root "{{project_path 'website/src'}}{{public.website.root}}" \
        --uri={{public.website.url}}
fi

# Drupal locks sites/default and its settings files to read-only (555/444) after installation,
# which stops git from switching or merging branches over them. Give the owner write access
# back, and set skip_permissions_hardening in settings.php so Drupal stops locking them again.
docker compose exec -T php sh -c '
d="{{project_path 'website/src'}}/web/sites/default"
if [ -d "$d" ]; then
    chmod u+w "$d" && find "$d" -maxdepth 1 -type f -name "*.php" -exec chmod u+w {} + || exit 1
    if [ -f "$d/settings.php" ] && ! grep -q "^.settings..skip_permissions_hardening" "$d/settings.php"; then
        printf "\n\$settings[\047skip_permissions_hardening\047] = TRUE;\n" >> "$d/settings.php"
    fi
fi
'
