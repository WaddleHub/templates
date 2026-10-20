# Re-point the public URL after a local URL change, or a deploy/push to a remote environment, and
# on a remote build the website.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# A push uploads the local .env to a remote that has none yet, so its SITE_URL still holds the
# local domain there. Here we rewrite SITE_URL to the domain configured for the target environment
# and restart Astro, which only reads .env (through astro.config.mjs) on start. On a remote, the
# site is built with it in between, and the restart serves that build.

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

# Rewrite SITE_URL in place. Read and written as UTF-8 without BOM, so the file keeps its LF
# line endings (Set-Content would write the ANSI code page and CRLF).
$path = (Resolve-Path $envFile).ProviderPath
$content = [IO.File]::ReadAllText($path)
$content = [regex]::Replace($content, '(?m)^SITE_URL=.*$', "SITE_URL=${scheme}://$targetDomain")
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

# Astro reads .env on start only.
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to restart Astro." }

Write-Host "[WADDLE] SITE_URL updated to ${scheme}://$targetDomain for $TargetEnv environment."

exit 0
