# Correct base URLs in the WordPress database after a database sync, or a local URL change.
# Usage: after_db_updated.ps1 <Local|Production|Stage|Dev>

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$wpPath = "{{project_path 'website/src'}}"

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

# wp search-replace handles serialized data safely.

# First replace the domain the database itself points at (its "home" option). It needn't be one
# this project still has configured: after a local URL change it's the previous URL, and after an
# import it can be a colleague's local URL or an environment's old domain. So it's read from the
# database at run time rather than baked in at render time. display_errors=stderr keeps PHP
# notices out of the captured value. stderr isn't redirected here, in Windows PowerShell 5.1 that
# turns any stderr line into a terminating error under $ErrorActionPreference = "Stop".
$dbUrl = docker compose exec -T php php -d display_errors=stderr "{{project_path 'bin'}}/wp" `
    option get home --path="$wpPath" --allow-root
if ($LASTEXITCODE -ne 0 -or -not $dbUrl) {
    throw "Couldn't read the site's home URL from the database."
}
$dbUrl = $dbUrl | Select-Object -Last 1
$dbDomain = ($dbUrl -replace '^[A-Za-z]+://', '') -replace '/.*$', ''

if ($dbDomain -notmatch '^[A-Za-z0-9.:-]+$') {
    throw "The site's home URL in the database isn't a valid URL: $dbUrl"
}

if ($dbDomain -ne $targetUrl) {
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace `
        $dbDomain $targetUrl --all-tables --path="$wpPath" --allow-root
    if ($LASTEXITCODE -ne 0) { throw "Failed to replace URLs." }
}

# Then replace any remaining references to the other configured environments' domains.
{{#if (not_empty public.website.url)}}
if ($TargetEnv -ne "Local" -and $dbDomain -ne "{{public.website.url}}") {
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace `
        "{{public.website.url}}" $targetUrl --all-tables --path="$wpPath" --allow-root
    if ($LASTEXITCODE -ne 0) { throw "Failed to replace URLs." }
}
{{/if}}
{{#if (not_empty public.remotes.production.domain)}}
if ($TargetEnv -ne "Production" -and $dbDomain -ne "{{public.remotes.production.domain}}") {
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace `
        "{{public.remotes.production.domain}}" $targetUrl --all-tables --path="$wpPath" --allow-root
    if ($LASTEXITCODE -ne 0) { throw "Failed to replace URLs." }
}
{{/if}}
{{#if (not_empty public.remotes.stage.domain)}}
if ($TargetEnv -ne "Stage" -and $dbDomain -ne "{{public.remotes.stage.domain}}") {
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace `
        "{{public.remotes.stage.domain}}" $targetUrl --all-tables --path="$wpPath" --allow-root
    if ($LASTEXITCODE -ne 0) { throw "Failed to replace URLs." }
}
{{/if}}
{{#if (not_empty public.remotes.dev.domain)}}
if ($TargetEnv -ne "Dev" -and $dbDomain -ne "{{public.remotes.dev.domain}}") {
    docker compose exec -T php "{{project_path 'bin'}}/wp" search-replace `
        "{{public.remotes.dev.domain}}" $targetUrl --all-tables --path="$wpPath" --allow-root
    if ($LASTEXITCODE -ne 0) { throw "Failed to replace URLs." }
}
{{/if}}

Write-Host "[WADDLE] URL replacement complete for $TargetEnv environment."
