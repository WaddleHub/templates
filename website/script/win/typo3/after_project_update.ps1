# Re-point the site base URL after a local URL change.
# Usage: after_project_update.ps1 <Local|Production|Stage|Dev>
#
# TYPO3 stores each site's base URL in website/src/config/sites/<identifier>/config.yaml (base:).
# Here we rewrite the base of every configured site to the target environment's domain and flush
# the cache.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

switch ($TargetEnv) {
    "Local"      { $targetDomain = "{{public.website.url}}" }
    "Production" { $targetDomain = "{{public.remotes.production.domain}}" }
    "Stage"      { $targetDomain = "{{public.remotes.stage.domain}}" }
    "Dev"        { $targetDomain = "{{public.remotes.dev.domain}}" }
    default {
        Write-Error "Usage: after_project_update.ps1 <Local|Production|Stage|Dev>"
        exit 1
    }
}

if (-not $targetDomain) {
    Write-Host "[WADDLE] No domain configured for $TargetEnv environment, skipping URL update."
    exit 0
}

{{#if ssl.enabled}}
$scheme = "https"
{{else}}
$scheme = "http"
{{/if}}

# Rewrite the base of every configured site in place. Read and written as UTF-8 without BOM, so
# each file keeps its LF line endings (Set-Content would write the ANSI code page and CRLF).
$configs = @(Get-ChildItem "./website/src/config/sites/*/config.yaml" -File -ErrorAction SilentlyContinue)

if ($configs.Count -eq 0) {
    throw "No site configuration found in website/src/config/sites."
}

foreach ($config in $configs) {
    $content = [IO.File]::ReadAllText($config.FullName)
    $content = [regex]::Replace($content, '(?m)^base:.*$', "base: '${scheme}://$targetDomain/'")
    [IO.File]::WriteAllText($config.FullName, $content, (New-Object Text.UTF8Encoding $false))
}

# Flush caches so the new base URL takes effect.
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush
if ($LASTEXITCODE -ne 0) { throw "Failed to flush the cache." }

Write-Host "[WADDLE] Site base URL updated to ${scheme}://$targetDomain/ for $TargetEnv environment."

exit 0
