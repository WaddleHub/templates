$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

docker compose exec -T db sh -c "find '{{project_path 'mariadb/data'}}/{{public.website.db_name}}' -iname '*core_config_data*' 2>/dev/null | grep -q ."
$hasMagentoDb = ($LASTEXITCODE -eq 0)

if ((Test-Path "./website/src/bin/magento" -PathType Leaf) -and $hasMagentoDb) {
    # Backup website source.
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1" `
            --exclude "var/cache var/page_cache var/log generated pub/media sample-data"
    }

    # Backup media data.
    if ($env:WADDLE_BACKUP_MEDIA -eq "0" -and (Test-Path "./website/src/pub/media" -PathType Container)) {
        Write-Host "[WADDLE] Backing up media data."
        # Use Windows' own bsdtar explicitly: GNU tar (e.g. Git for Windows' usr\bin) reads C:\... as a
        # remote host:path archive, and which tar comes first on PATH isn't predictable.
        & "$env:SystemRoot\System32\tar.exe" -C "./website/src" -czf "$env:WADDLE_BUILD_DIR/media.tar.gz" pub/media
        if ($LASTEXITCODE -ne 0) { throw "Failed to back up media data." }
    }

    # Enable maintenance mode.
    Write-Host "[WADDLE NOTICE] Enabling Magento maintenance mode."
    docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:enable

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    # Install Magento.
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}

{{#if public.redis.install}}
Write-Host "[WADDLE] Configuring Redis cache."
"yes" | docker compose exec -i php "{{project_path 'website/src'}}/bin/magento" setup:config:set --cache-backend=redis --cache-backend-redis-server=redis
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Redis cache backend." }
"yes" | docker compose exec -i php "{{project_path 'website/src'}}/bin/magento" setup:config:set --page-cache=redis --page-cache-redis-server=redis
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Redis page cache." }
"yes" | docker compose exec -i php "{{project_path 'website/src'}}/bin/magento" setup:config:set --session-save=redis --session-save-redis-host=redis
if ($LASTEXITCODE -ne 0) { throw "Failed to configure Redis session storage." }
{{else}}
"yes" | docker compose exec -i php "{{project_path 'website/src'}}/bin/magento" setup:config:set --session-save=files
if ($LASTEXITCODE -ne 0) { throw "Failed to configure file-based session storage." }
{{/if}}

# Set deployment mode. The installer only runs locally; remotes switch to production mode in the
# after_project_update.sh and after_db_updated.sh hooks (see unix/magento/deploy.sh).
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" deploy:mode:set developer
if ($LASTEXITCODE -ne 0) { throw "Failed to set deployment mode." }

Write-Host "[WADDLE] Running migrations."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:upgrade
{{#if public.website.deploy_sample_data}}
if ($LASTEXITCODE -ne 0) { Write-Host "[WADDLE ERROR] Please attempt freeing some disk space." }
{{else}}
if ($LASTEXITCODE -ne 0) { throw "Failed to run migrations." }
{{/if}}

Write-Host "[WADDLE] Compiling DI."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" setup:di:compile
if ($LASTEXITCODE -ne 0) { throw "Failed to compile DI." }

Write-Host "[WADDLE] Refreshing indexes."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" indexer:reindex
if ($LASTEXITCODE -ne 0) { Write-Host "[WADDLE WARNING] One or more indexes failed to reindex. You may need to reindex manually." }

Write-Host "[WADDLE] Refreshing caches."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" cache:flush
if ($LASTEXITCODE -ne 0) { throw "Failed to refresh caches." }

Write-Host "[WADDLE] Disabling maintenance mode."
docker compose exec -T php "{{project_path 'website/src'}}/bin/magento" maintenance:disable
if ($LASTEXITCODE -ne 0) { throw "Failed to disable maintenance mode." }
