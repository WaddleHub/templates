$ErrorActionPreference = "Stop"

# Create or restore a tar.gz snapshot of the website source directory.

# Path to apply the backup operation on.
$path = "./website/src"

# Path to the tar file. Defaults to the build directory's source snapshot when available.
$tarPath = ""
if ($env:WADDLE_BUILD_DIR) {
    $tarPath = "$($env:WADDLE_BUILD_DIR)/src.tar.gz"
}

# Space-separated list of patterns to exclude (relative to $path), and whether we restore.
$exclude = ""
$restore = $false

# Resolve arguments.
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--restore" { $restore = $true }
        "--exclude" { $exclude = $args[++$i] }
        "--tarPath" { $tarPath = $args[++$i] }
    }
}

# Ensure a tar path has been resolved.
if (-not $tarPath) {
    Write-Host "[WADDLE ERROR] No tar path specified."
    exit 1
}

# The archive is handled inside a container that only mounts the project directory, so it must be
# addressed relative to it.
#
# Resolving first also strips the provider prefix (Microsoft.PowerShell.Core\FileSystem::) that
# paths built from Get-Location carry on a \\wsl.localhost\... location.
$projectPrefix = (Get-Location).ProviderPath.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
$fullTarPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($tarPath)

if (-not $fullTarPath.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[WADDLE ERROR] Tar path $tarPath is outside the project directory."
    exit 1
}

$tarPath = "./" + ($fullTarPath.Substring($projectPrefix.Length) -replace "\\", "/")

# The exclude patterns used when creating the backup, kept so a restore leaves the same paths alone.
$excludePath = "$tarPath.exclude"

if ($restore) {
    Write-Host "[WADDLE] Restoring backup $tarPath to $path"

    if (-not (Test-Path $tarPath -PathType Leaf)) {
        Write-Host "[WADDLE ERROR] No tar file found at $tarPath."
        exit 1
    }

    if (Test-Path $excludePath -PathType Leaf) {
        $exclude = "$(Get-Content $excludePath -Raw)".Trim()
    }

    # Anything the failed build added is removed as well, so the source matches the backup exactly.
    if ($exclude) {
        & "./bin/deploy/file-task.ps1" restore $tarPath $path --exclude $exclude
    } else {
        & "./bin/deploy/file-task.ps1" restore $tarPath $path
    }
} else {
    Write-Host "[WADDLE] Creating backup of $path at $tarPath"

    if (-not (Test-Path $path -PathType Container)) {
        Write-Host "[WADDLE ERROR] $path is not a directory."
        exit 1
    }

    # Create the destination directory if it does not exist.
    $tarDir = Split-Path -Parent $tarPath
    if ($tarDir -and -not (Test-Path $tarDir -PathType Container)) {
        New-Item -ItemType Directory -Path $tarDir -Force | Out-Null
    }

    Set-Content -Path $excludePath -Value $exclude -Encoding utf8

    if ($exclude) {
        & "./bin/deploy/file-task.ps1" archive $tarPath $path --exclude $exclude .
    } else {
        & "./bin/deploy/file-task.ps1" archive $tarPath $path .
    }
}
