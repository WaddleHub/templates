# Re-point the allowed HTTP host after a local URL change.
# Usage: after_project_update.ps1 <Local|Production|Stage|Dev>
#
# ProcessWire validates the request host against $config->httpHosts in website/src/site/config.php.
# Here we rewrite httpHosts to the target environment's domain.

param([string]$TargetEnv = "")

$ErrorActionPreference = "Stop"

$configFile = "./website/src/site/config.php"

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
    Write-Host "[WADDLE] No domain configured for $TargetEnv environment, skipping host update."
    exit 0
}

if (-not (Test-Path $configFile -PathType Leaf)) {
    throw "$configFile not found."
}

# Rewrite the httpHosts entry in place. Read and written as UTF-8 without BOM, so the file keeps
# its LF line endings (Set-Content would write the ANSI code page and CRLF). "$$" is a literal "$"
# in a .NET regex replacement.
$path = (Resolve-Path $configFile).ProviderPath
$content = [IO.File]::ReadAllText($path)
$content = [regex]::Replace(
    $content,
    '\$config->httpHosts = array\(.*\);',
    ("`$`$config->httpHosts = array('" + $targetDomain + "');")
)
[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding $false))

Write-Host "[WADDLE] httpHosts updated to $targetDomain for $TargetEnv environment."

exit 0
