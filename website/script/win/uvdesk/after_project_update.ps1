# Re-point the application URL after a local URL change.
# Usage: after_project_update.ps1 <Local|Production|Stage|Dev>
#
# The application .env is uploaded verbatim from the local environment on the first push (so the
# remote shares the same keys the synced database relies on). Its APP_URL therefore holds the
# domain it was written with. Here we rewrite APP_URL to the domain configured for the target
# environment and clear the Symfony cache.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$envFile = "./website/src/.env"

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

if (-not (Test-Path $envFile -PathType Leaf)) {
    throw "$envFile not found."
}

{{#if ssl.enabled}}
$scheme = "https"
{{else}}
$scheme = "http"
{{/if}}

# Rewrite APP_URL in place. Read and written as UTF-8 without BOM, so the file keeps its LF line
# endings (Set-Content would write the ANSI code page and CRLF).
$path = (Resolve-Path $envFile).ProviderPath
$content = [IO.File]::ReadAllText($path)
$content = [regex]::Replace($content, '(?m)^APP_URL=.*$', "APP_URL=${scheme}://$targetDomain")
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

# Clear the Symfony cache so the new APP_URL takes effect.
docker compose exec -T php php "{{project_path 'website/src'}}/bin/console" cache:clear --env=prod
if ($LASTEXITCODE -ne 0) { throw "Failed to clear the cache." }

Write-Host "[WADDLE] APP_URL updated to ${scheme}://$targetDomain for $TargetEnv environment."

exit 0
