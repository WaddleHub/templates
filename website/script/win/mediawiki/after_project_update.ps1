# Re-point the wiki server URL after a local URL change.
# Usage: after_project_update.ps1 <Local|Production|Stage|Dev>
#
# MediaWiki stores its canonical server URL in website/src/w/LocalSettings.php ($wgServer). Here
# we rewrite it to the target environment's domain.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$configFile = "./website/src/w/LocalSettings.php"

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

# Rewrite $wgServer in place. Read and written as UTF-8 without BOM, so the file keeps its LF line
# endings (Set-Content would write the ANSI code page and CRLF). "$$" is a literal "$" in a .NET
# regex replacement.
$path = (Resolve-Path $configFile).ProviderPath
$content = [IO.File]::ReadAllText($path)
$content = [regex]::Replace(
    $content,
    '(?m)^\$wgServer = .*$',
    ('$$wgServer = "' + $scheme + '://' + $targetDomain + '";')
)
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

Write-Host "[WADDLE] `$wgServer updated to ${scheme}://$targetDomain for $TargetEnv environment."

exit 0
