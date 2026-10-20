# Correct base URLs in the PrestaShop database after a database sync.
# Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

# This script can run outside the main build flow (which runs bin/deploy/set-env), e.g. after a
# database sync. Load the project's gitignored .env so $env:WADDLE_DB_USER /
# $env:WADDLE_DB_PASSWORD (written by Waddle) are available.
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#=][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim("'"), "Process")
        }
    }
}

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

if (-not $targetUrl) {
    Write-Host "[WADDLE] No domain configured for $TargetEnv environment, skipping URL update."
    exit 0
}

# Passed with -e rather than piped: PowerShell can add a BOM and a stray "\r" to native stdin.
$sql = "UPDATE ps_shop_url SET domain='$targetUrl', domain_ssl='$targetUrl' WHERE id_shop=1; " +
    "UPDATE ps_configuration SET value='$targetUrl' WHERE name='PS_SHOP_DOMAIN'; " +
    "UPDATE ps_configuration SET value='$targetUrl' WHERE name='PS_SHOP_DOMAIN_SSL';"

docker compose exec -T db mysql `
    -u "${env:WADDLE_DB_USER}" `
    -p"${env:WADDLE_DB_PASSWORD}" `
    -e $sql `
    "{{public.website.db_name}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update shop URLs." }

Write-Host "[WADDLE] URL replacement complete for $TargetEnv environment."
