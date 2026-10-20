# Re-point CodeIgniter's base URL after a local URL change, or a deploy/push to a remote environment.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# website/src/.env is copied verbatim from the local environment during a push, so its app.baseURL
# still holds the local domain. Here we rewrite it to the domain configured for the target
# environment.

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

{{#if ssl.enabled}}
$scheme = "https"
{{else}}
$scheme = "http"
{{/if}}

$baseUrl = "app.baseURL = '${scheme}://$targetDomain/'"

# Read and written as UTF-8 without BOM, so the file keeps its LF line endings (Set-Content would
# write the ANSI code page and CRLF).
$content = ""
if (Test-Path $envFile -PathType Leaf) {
    $content = [IO.File]::ReadAllText((Resolve-Path $envFile).ProviderPath)
}

if ($content -match '(?m)^app\.baseURL') {
    $content = [regex]::Replace($content, '(?m)^app\.baseURL.*$', $baseUrl)
} else {
    if ($content -and -not $content.EndsWith("`n")) {
        $content += "`n"
    }
    $content += "$baseUrl`n"
}

$path = [IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath $envFile))
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

Write-Host "[WADDLE] app.baseURL updated to ${scheme}://$targetDomain/ for $TargetEnv environment."

exit 0
