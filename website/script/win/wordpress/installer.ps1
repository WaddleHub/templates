$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

# Update WP CLI.
Write-Host "[WADDLE] Downloading WP CLI."
$wpCliUrl = "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
$statusCode = (Invoke-WebRequest -Uri $wpCliUrl -Method Head -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode

if ($statusCode -ne 200) {
    Write-Host "[WADDLE ERROR] Failed to find WP CLI download."
    exit 1
}

$wpBin = "./bin/wp"

if (Test-Path $wpBin -PathType Leaf) {
    Remove-Item $wpBin -Force
}

Invoke-WebRequest -Uri $wpCliUrl -OutFile $wpBin -UseBasicParsing

# A file written from Windows lands without the executable bit, so set it inside the container.
docker compose exec -T -u 0 php chmod +x "{{project_path 'bin'}}/wp"
if ($LASTEXITCODE -ne 0) { throw "Failed to make WP CLI executable." }

$dirContents = Get-ChildItem ./website/src -ErrorAction SilentlyContinue
if ($dirContents -and $dirContents.Count -gt 0) {
    # Backup website source.
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1"
    }

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    # Install website.
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}
