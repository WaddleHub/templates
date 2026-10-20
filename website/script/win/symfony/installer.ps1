$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

# Download latest version of symfony-cli. It only ever runs inside the php container, which is
# always Linux, so fetch the Linux build matching the host CPU architecture.
switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $symfonyArch = "amd64" }
    "ARM64" { $symfonyArch = "arm64" }
    default {
        Write-Host "[WADDLE ERROR] Unsupported host architecture for symfony-cli: $($env:PROCESSOR_ARCHITECTURE)"
        exit 1
    }
}

$releasesJson = Invoke-RestMethod -Uri "https://api.github.com/repos/symfony-cli/symfony-cli/releases/latest" -UseBasicParsing
$downloadUrl = $releasesJson.assets |
    Where-Object { $_.browser_download_url -like "*linux_${symfonyArch}.tar.gz" } |
    Select-Object -ExpandProperty browser_download_url

if (-not $downloadUrl) {
    Write-Host "[WADDLE ERROR] Could not find symfony-cli download URL for linux_${symfonyArch}."
    exit 1
}

# Download and extract to a temp directory first so a failed or corrupt download
# does not leave a partial binary in the project's bin/ directory.
$tmpTar = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "symfony.tar.gz")
$tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "symfony-cli")
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpTar -UseBasicParsing
# Use Windows' own bsdtar explicitly: GNU tar (e.g. Git for Windows' usr\bin) reads C:\... as a
# remote host:path archive, and which tar comes first on PATH isn't predictable.
& "$env:SystemRoot\System32\tar.exe" -C $tmpDir -xzf $tmpTar
if ($LASTEXITCODE -ne 0) { throw "Failed to extract symfony-cli archive." }

if (-not (Test-Path "$tmpDir/symfony")) {
    Write-Host "[WADDLE ERROR] Archive missing symfony binary."
    exit 1
}

Copy-Item "$tmpDir/symfony" "./bin/symfony" -Force
# A file written from Windows lands without the executable bit, so set it inside the container.
docker compose exec -T -u 0 php chmod +x "{{project_path 'bin'}}/symfony"
if ($LASTEXITCODE -ne 0) { throw "Failed to make symfony-cli executable." }
Remove-Item $tmpTar -Force
Remove-Item $tmpDir -Recurse -Force

$dirContents = Get-ChildItem ./website/src -ErrorAction SilentlyContinue
if ($dirContents -and $dirContents.Count -gt 0) {
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1"
    }
    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}
