$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

$dirContents = Get-ChildItem "./website/src/public" -ErrorAction SilentlyContinue
if ($dirContents -and $dirContents.Count -gt 0) {
    # Backup website source.
    if ($env:WADDLE_BACKUP_SRC -eq "0") {
        & "./bin/web/backup.ps1"
    }

    # Upgrade procedures are experimental and currently disabled by default. You can enable the
    # upgrade script by uncommenting the line below, but if you do, we urge you to take backups of
    # your source code before running builds, unless your website source is already included in the
    # project git repository.
    # if (Test-Path "./website/src/vendor/bin/typo3" -PathType Leaf) {
    #     docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" maintenance:enable
    # }

    # Upgrade TYPO3.
    # . ./website/script/win/$env:WADDLE_PLATFORM/upgrade.ps1
} else {
    # Install TYPO3.
    . ./website/script/win/$env:WADDLE_PLATFORM/install.ps1
}
