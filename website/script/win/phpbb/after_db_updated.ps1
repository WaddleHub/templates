# Correct the board URL in the phpBB database after a database sync, or a local URL change.
# Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>
#
# phpBB stores the canonical host, protocol and cookie domain in the phpbb_config table
# (server_name, server_protocol, cookie_domain). After importing a database from another
# environment those values point at the wrong domain, so we rewrite them for the target
# environment and purge the cache.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

# This script can run outside the main build flow (which runs bin/deploy/set-env), e.g. after a
# database sync. Load the project's gitignored .env so $env:WADDLE_DB_USER / $env:WADDLE_DB_PASSWORD
# (written by Waddle) are available.
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#=][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim("'"), "Process")
        }
    }
}

switch ($TargetEnv) {
    "Local"      { $targetDomain = "{{public.website.url}}" }
    "Production" { $targetDomain = "{{public.remotes.production.domain}}" }
    "Stage"      { $targetDomain = "{{public.remotes.stage.domain}}" }
    "Dev"        { $targetDomain = "{{public.remotes.dev.domain}}" }
    default {
        Write-Error "Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>"
        exit 1
    }
}

if (-not $targetDomain) {
    Write-Host "[WADDLE] No domain configured for $TargetEnv environment, skipping URL update."
    exit 0
}

{{#if ssl.enabled}}
$scheme = "https"
$cookieSecure = "1"
{{else}}
$scheme = "http"
$cookieSecure = "0"
{{/if}}

# Passed with -e rather than piped: PowerShell can add a BOM and a stray "\r" to native stdin.
$sql = "UPDATE phpbb_config SET config_value='$targetDomain' WHERE config_name='server_name'; " +
    "UPDATE phpbb_config SET config_value='$targetDomain' WHERE config_name='cookie_domain'; " +
    "UPDATE phpbb_config SET config_value='${scheme}://' WHERE config_name='server_protocol'; " +
    "UPDATE phpbb_config SET config_value='$cookieSecure' WHERE config_name='cookie_secure';"

docker compose exec -T db mysql `
    -u "${env:WADDLE_DB_USER}" `
    -p"${env:WADDLE_DB_PASSWORD}" `
    -e $sql `
    "{{public.website.db_name}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to update the board URL." }

# Purge the phpBB cache so the new configuration is reloaded.
docker compose exec -T php php "{{project_path 'website/src'}}/phpBB/bin/phpbbcli.php" cache:purge
if ($LASTEXITCODE -ne 0) { throw "Failed to clear the cache." }

Write-Host "[WADDLE] Board URL updated to ${scheme}://$targetDomain for $TargetEnv environment."

exit 0
