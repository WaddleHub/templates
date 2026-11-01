$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

$dirContents = Get-ChildItem "./website/src/web" -ErrorAction SilentlyContinue
if ($dirContents -and $dirContents.Count -gt 0) {
    # Backup source code before running upgrade.
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1"
    }
    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    # Run installation script.
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}

Write-Host "[WADDLE NOTICE] Installing Drush"
{{#if (version_compare tags.website.version.raw '>=' '11.0.0')}}
docker compose exec -T php composer require drush/drush:"^13" `
    --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to install Drush." }
{{else}}
{{#if (version_compare tags.website.version.raw '>=' '10.0.0')}}
docker compose exec -T php composer require drush/drush:"^12" `
    --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to install Drush." }
{{else}}
docker compose exec -T php composer require drush/drush:"^11" `
    --working-dir="{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to install Drush." }
{{/if}}
{{/if}}

# Run installer, if database is empty.
docker compose exec -T db sh -c "ls '{{project_path 'mariadb/data'}}/{{public.website.db_name}}'/*.ibd >/dev/null 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WADDLE NOTICE] Running installation routine."

    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/drush" si standard `
        --account-mail="{{public.website.admin_email}}" `
        --account-name="{{public.website.admin_username}}" `
        --account-pass="$env:WADDLE_ADMIN_PASSWORD" `
        --db-url="mysql://${env:WADDLE_DB_USER}:${env:WADDLE_DB_PASSWORD}@db/{{public.website.db_name}}" `
        --yes --no-interaction `
        --root "{{project_path 'website/src'}}{{public.website.root}}" `
        --uri={{public.website.url}}
    if ($LASTEXITCODE -ne 0) { throw "Failed to run the installation routine." }
}

# Drupal locks sites/default and its settings files to read-only (555/444) after installation,
# which stops git from switching or merging branches over them. Give the owner write access
# back, and set skip_permissions_hardening in settings.php so Drupal stops locking them again.
# Piped via stdin: Windows PowerShell 5.1 strips embedded double quotes from native-command arguments.
@'
d="{{project_path 'website/src'}}/web/sites/default"
if [ -d "$d" ]; then
    chmod u+w "$d" && find "$d" -maxdepth 1 -type f -name "*.php" -exec chmod u+w {} + || exit 1
    if [ -f "$d/settings.php" ] && ! grep -q "^.settings..skip_permissions_hardening" "$d/settings.php"; then
        printf "\n\$settings[\047skip_permissions_hardening\047] = TRUE;\n" >> "$d/settings.php"
    fi
fi
'@ | docker compose exec -T php sh -c "tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to restore write access to sites/default." }
