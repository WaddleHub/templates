$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

$dirContents = Get-ChildItem "./website/src" -ErrorAction SilentlyContinue
if ($dirContents -and $dirContents.Count -gt 0) {
    # Backup website source code.
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1" `
            --exclude "storage/logs storage/framework/cache bootstrap/cache"
    }

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # if (Test-Path "./website/src/artisan" -PathType Leaf) {
    #     Write-Host "[WADDLE NOTICE] Enabling maintenance mode."
    #     docker compose exec -T php php "{{project_path 'website/src'}}/artisan" down
    # }

    # Upgrade website.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    # Install website.
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}
