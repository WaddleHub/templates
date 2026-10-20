$ErrorActionPreference = "Stop"

. ./bin/deploy/set-env.ps1 @args

# Ensures a docker service is running, starting or unpausing it if needed.
#
# Returns $true if the service is up after the call, $false if it is not present in the compose config.
function EnsureServiceUp {
    param (
        [string]$serviceName
    )

    if (docker compose ps --services $serviceName --status paused) {
        docker compose unpause $serviceName | Out-Null
        return $true
    }

    if (docker compose ps --services $serviceName --status exited) {
        docker compose up -d $serviceName | Out-Null
        return $true
    }

    if (docker compose ps --services $serviceName --status running) {
        return $true
    }

    return $false
}

Write-Host "[WADDLE NOTICE] Executing rollback."

if ($env:WADDLE_BUILD_TAG -eq (git branch --show-current)) {
    Write-Host "[WADDLE] Resetting repository."
    # Checkout, reset and clean run inside the WSL2 distro, so the files they restore get their
    # executable bits back (see set-env.ps1).
    Invoke-DistroGit checkout -f $env:WADDLE_ORIGINAL_BRANCH
    if ($LASTEXITCODE -ne 0) { throw "Failed to reset repository." }
    Invoke-DistroGit reset --hard HEAD
    if ($LASTEXITCODE -ne 0) { throw "Failed to reset repository." }
    Invoke-DistroGit clean -fd
    if ($LASTEXITCODE -ne 0) { throw "Failed to reset repository." }
}

# Drop the build branch ref now that we are back on the original branch. A
# failed build branch holds no value and lingering refs accumulate over time.
git show-ref --verify --quiet "refs/heads/$($env:WADDLE_BUILD_TAG)"
if ($LASTEXITCODE -eq 0) {
    Write-Host "[WADDLE] Dropping build branch $($env:WADDLE_BUILD_TAG)."
    git branch -D "$env:WADDLE_BUILD_TAG"
    if ($LASTEXITCODE -ne 0) { throw "Failed to drop build branch." }
}

if (Test-Path "./builder/$($env:WADDLE_BUILD_TAG)/stash.tar.gz" -PathType Leaf) {
    Write-Host "[WADDLE] Extracting config stash."
    $stashed = @()

    if (Test-Path "./builder/$($env:WADDLE_BUILD_TAG)/stash.txt" -PathType Leaf) {
        $stashed = "$(Get-Content "./builder/$($env:WADDLE_BUILD_TAG)/stash.txt" -Raw)".Trim() -split '\s+'
    }

    & "./bin/deploy/file-task.ps1" replace "./builder/$($env:WADDLE_BUILD_TAG)/stash.tar.gz" @stashed
}

# Rebuild services BEFORE restoring the DB dump - if the build broke while
# rebuilding the database image, we must first bring up the original (now
# restored) image before any dump can be imported into it.
#
# services.txt records the services that existed before the build started. A
# build can add or remove services (e.g. adding Redis, dropping OpenSearch), so
# we cannot rely on the current docker-compose.yml to know what was running.
# Rebuilding from this snapshot reinstates exactly the pre-build service set.
#
# A service that fails to come back must not stop the database restore below, so the failure is
# reported once everything else has been restored.
$servicesFailed = $false

if (Test-Path "./builder/$($env:WADDLE_BUILD_TAG)/services.txt" -PathType Leaf) {
    Write-Host "[WADDLE] Rebuilding services."
    $services = "$(Get-Content "./builder/$($env:WADDLE_BUILD_TAG)/services.txt" -Raw)".Trim()

    if ($services) {
        docker compose build ($services -split '\s+')
        if ($LASTEXITCODE -ne 0) { $servicesFailed = $true }
        docker compose up -d
        if ($LASTEXITCODE -ne 0) { $servicesFailed = $true }
    }
}

if ((Test-Path "./builder/$($env:WADDLE_BUILD_TAG)/db.tar.gz" -PathType Leaf) -and (EnsureServiceUp db)) {
    Write-Host "[WADDLE] Importing database backup."
    & "$env:SystemRoot\System32\tar.exe" -C "./builder/$($env:WADDLE_BUILD_TAG)" -xzf "./builder/$($env:WADDLE_BUILD_TAG)/db.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract database backup." }
    # Stream the dump via a bind-mounted path rather than piping from the host.
    # This is to avoid data corruption caused by encoding differences between the host
    # and container that may occur when piping directly. restore.sh replaces the current
    # databases, so nothing created since the backup survives.
    $restoreSql = "./mariadb/.waddle_restore.sql"
    Copy-Item "./builder/$($env:WADDLE_BUILD_TAG)/db.sql" $restoreSql
    try {
        docker compose exec -u 0 -T db sh "{{project_path 'mariadb/script/restore.sh'}}" "{{project_path 'mariadb'}}/.waddle_restore.sql"
        if ($LASTEXITCODE -ne 0) { throw "Failed to import database backup." }
    } finally {
        Remove-Item -Force $restoreSql -ErrorAction SilentlyContinue
    }
}

# Resotre backed up website src if any.
if (Test-Path "$($env:WADDLE_BUILD_DIR)/src.tar.gz" -PathType Leaf) {
    Write-Host "[WADDLE] Restoring source directory content from backup."
    & "./bin/web/backup.ps1" --restore
}

# Execute platform/blurprint specific rollback script if any.
$rollback = "./website/script/win/$($env:WADDLE_PLATFORM)/rollback.ps1"

if (Test-Path $rollback -PathType Leaf) {
    Write-Host "[WADDLE] Executing website rollback script."
    & $rollback
}

if ($servicesFailed) { throw "Failed to start services." }

# Cleanup build artifacts if requested.
if ($env:WADDLE_CLEAN -eq "0" -and $env:WADDLE_BUILD_TAG) {
    Write-Host "[WADDLE] Cleaning up."
    Remove-Item -Recurse -Force "./builder/$($env:WADDLE_BUILD_TAG)"
}
