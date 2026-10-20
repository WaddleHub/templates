# Re-point the forum URL after a local URL change.
# Usage: after_project_update.ps1 <Local|Production|Stage|Dev>
#
# Flarum stores its canonical URL in website/src/config.php ('url' => ...). Here we rewrite it to
# the target environment's domain and clear Flarum's cache.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$configFile = "./website/src/config.php"

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

if (-not (Test-Path $configFile -PathType Leaf)) {
    throw "$configFile not found."
}

{{#if ssl.enabled}}
$scheme = "https"
{{else}}
$scheme = "http"
{{/if}}

# Rewrite the 'url' entry in place. Read and written as UTF-8 without BOM, so the file keeps its
# LF line endings (Set-Content would write the ANSI code page and CRLF).
$path = (Resolve-Path $configFile).ProviderPath
$content = [IO.File]::ReadAllText($path)
$content = [regex]::Replace($content, "'url' => '[^']*'", "'url' => '${scheme}://$targetDomain'")
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

# Clear Flarum's cache so the new URL takes effect.
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" cache:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear the cache." }

Write-Host "[WADDLE] Forum URL updated to ${scheme}://$targetDomain for $TargetEnv environment."

exit 0
