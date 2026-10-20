$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installer."

if ((Get-ChildItem "./website/src" -ErrorAction SilentlyContinue).Count -gt 0) {
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
