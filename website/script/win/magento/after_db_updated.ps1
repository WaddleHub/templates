# Correct base URLs in the Magento database after a database sync, or a local URL change, then
# apply schema and data patches, reindex and flush the cache.
# Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$binMagento = "{{project_path 'website/src'}}/bin/magento"

switch ($TargetEnv) {
    "Local"      { $targetUrl = "{{public.website.url}}" }
    "Production" { $targetUrl = "{{public.remotes.production.domain}}" }
    "Stage"      { $targetUrl = "{{public.remotes.stage.domain}}" }
    "Dev"        { $targetUrl = "{{public.remotes.dev.domain}}" }
    default {
        Write-Error "Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>"
        exit 1
    }
}

{{#if ssl.enabled}}
$scheme = "https"
{{else}}
$scheme = "http"
{{/if}}

if (-not $targetUrl) {
    Write-Host "[WADDLE] No domain configured for $TargetEnv environment, skipping URL update."
} else {
    docker compose exec -T php $binMagento config:set web/unsecure/base_url "${scheme}://$targetUrl/"
    if ($LASTEXITCODE -ne 0) { throw "Failed to set the unsecure base URL." }
    docker compose exec -T php $binMagento config:set web/secure/base_url "https://$targetUrl/"
    if ($LASTEXITCODE -ne 0) { throw "Failed to set the secure base URL." }

    Write-Host "[WADDLE] URL replacement complete for $TargetEnv environment."
}

# Skip the deployment steps while the database holds no Magento install.
$tableCount = docker compose exec -u 0 -T db mariadb -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '{{public.website.db_name}}' AND table_name = 'core_config_data'"
if ($LASTEXITCODE -ne 0) { throw "Failed to query the database." }
if ("$tableCount".Trim() -ne "1") {
    Write-Host "[WADDLE NOTICE] No Magento database here yet. Deployment steps will run once the database is uploaded."
    exit 0
}

Write-Host "[WADDLE] Applying schema and data patches."
docker compose exec -T php $binMagento setup:upgrade
if ($LASTEXITCODE -ne 0) { throw "Failed to apply schema and data patches." }

# A failed index doesn't take the site down, so it's reported rather than fatal.
Write-Host "[WADDLE] Refreshing indexes."
docker compose exec -T php $binMagento indexer:reindex
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WADDLE WARNING] One or more indexes failed to reindex. You may need to reindex manually."
}

docker compose exec -T php $binMagento cache:flush
if ($LASTEXITCODE -ne 0) { throw "Failed to flush the cache." }
