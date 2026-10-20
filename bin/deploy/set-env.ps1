Write-Host "[WADDLE NOTICE] Setting up environment variables."

# Validate project directory content.
if (-not (Test-Path .config.public.json -PathType Leaf)) {
    Write-Host "[WADDLE ERROR] Public project configuration not found."
    exit 1
}

# Always required here: this script only runs locally, as remotes run the sh version.
if (-not (Test-Path .config.private.json -PathType Leaf)) {
    Write-Host "[WADDLE ERROR] Private project configuration not found."
    exit 1
}


# Make sure project directory is a git repository.
if (-not (Test-Path .git -PathType Container)) {
    Write-Host "[WADDLE ERROR] Project is not a git repository."
    exit 1
}

# Set default values for all variables (to ensure they are set).
############################################

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[WADDLE ERROR] git is not available."
    exit 1
}

$currentBranch = git branch --show-current

if (-not $currentBranch) {
    Write-Host "[WADDLE ERROR] Project is in a detached HEAD state."
    exit 1
}

# Build tag. Reuse the branch name when resuming an existing build, otherwise mint a new one.
if ($currentBranch.StartsWith("waddle-build-")) {
    $env:WADDLE_BUILD_TAG = $currentBranch
} else {
    $env:WADDLE_BUILD_TAG = "waddle-build-" + [int](Get-Date -UFormat %s)
}

# Original branch (before any git operations).
$env:WADDLE_ORIGINAL_BRANCH = $currentBranch

# Runs git inside the WSL2 distro that holds the project, for every step that reads or writes the
# project's files. Windows reaches the project through \\wsl.localhost, where it can neither read
# nor set Unix mode bits, can't read a Linux symlink, and is held to the 260-character path limit.
# Git for Windows would commit new scripts as non-executable, write every file it checks out as
# 644, and fail on a platform's deep paths. Git in the distro works on its own filesystem, as the
# files' owner. core.filemode and core.symlinks are set per command, so the repository's own
# settings (false, as Windows git needs them) never change.
function Invoke-DistroGit {
    $location = (Get-Location).ProviderPath

    if ($location -notmatch '^\\\\(?:wsl\.localhost|wsl\$)\\([^\\]+)(.*)$') {
        git @args
        return
    }

    $distro = $Matches[1]
    $linuxPath = $Matches[2] -replace '\\', '/'
    if (-not $linuxPath) { $linuxPath = "/" }

    $identity = @()
    $name = git config user.name
    if ($name) { $identity += @("-c", "user.name=$name") }
    $email = git config user.email
    if ($email) { $identity += @("-c", "user.email=$email") }

    wsl.exe -d $distro -e git -C $linuxPath -c core.filemode=true -c core.symlinks=true @identity @args
}

# Resolve config-derived defaults when jq is available; fall back to empty strings otherwise.
if (Get-Command jq -ErrorAction SilentlyContinue) {
    # Platform.
    $env:WADDLE_PLATFORM = (jq -r .website.platform .config.public.json)

    # DB name.
    $env:WADDLE_DB_NAME = (jq -r .website.db_name .config.public.json)

    # Whether SSL is enabled.
    $httpsPort = (jq -r .nginx.https_port .config.public.json)
    if ($httpsPort -and $httpsPort -ne "null") {
        $env:WADDLE_SSL = "0"
    } else {
        $env:WADDLE_SSL = ""
    }

    # Website URL.
    $env:WADDLE_WEBSITE_URL = (jq -r .website.url .config.public.json)

    # Whether to install Composer.
    if ((jq -r .composer.install .config.public.json) -eq "true") {
        $env:WADDLE_INSTALL_COMPOSER = "0"
    } else {
        $env:WADDLE_INSTALL_COMPOSER = ""
    }

    # Whether to install PhpMyAdmin.
    if ((jq -r .phpmyadmin.install .config.public.json) -eq "true") {
        $env:WADDLE_INSTALL_PHPMYADMIN = "0"
    } else {
        $env:WADDLE_INSTALL_PHPMYADMIN = ""
    }

    $env:WADDLE_DB_USER = (jq -r '.website_credentials.db_username // empty' .config.private.json)
    $env:WADDLE_DB_PASSWORD = (jq -r '.website_credentials.db_password // empty' .config.private.json)
    $env:WADDLE_ADMIN_PASSWORD = (jq -r '.website_credentials.admin_password // empty' .config.private.json)
} else {
    $env:WADDLE_PLATFORM = ""
    $env:WADDLE_DB_NAME = ""
    $env:WADDLE_SSL = ""
    $env:WADDLE_WEBSITE_URL = ""
    $env:WADDLE_INSTALL_COMPOSER = ""
    $env:WADDLE_INSTALL_PHPMYADMIN = ""
    $env:WADDLE_DB_USER = ""
    $env:WADDLE_DB_PASSWORD = ""
    $env:WADDLE_ADMIN_PASSWORD = ""
}

# Unresolvable values.
$env:WADDLE_RUN_PLATFORM_INSTALLER = ""
$env:WADDLE_BACKUP_MEDIA = ""
$env:WADDLE_BACKUP_SRC = ""
$env:WADDLE_CLEAN = ""
$env:WADDLE_DROP_DB = ""
$env:WADDLE_KEEP_BUILD_BRANCH = ""
$env:WADDLE_REMOTE = ""

# Resolve arguments and override the defaults above.
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--build-tag" { $env:WADDLE_BUILD_TAG = $args[++$i] }
        "--original-branch" { $env:WADDLE_ORIGINAL_BRANCH = $args[++$i] }
        "--platform" { $env:WADDLE_PLATFORM = $args[++$i] }
        "--db-name" { $env:WADDLE_DB_NAME = $args[++$i] }
        "--url" { $env:WADDLE_WEBSITE_URL = $args[++$i] }
        "--ssl" { $env:WADDLE_SSL = "0" }
        "--install-composer" { $env:WADDLE_INSTALL_COMPOSER = "0" }
        "--install-phpmyadmin" { $env:WADDLE_INSTALL_PHPMYADMIN = "0" }
        "--run-platform-installer" { $env:WADDLE_RUN_PLATFORM_INSTALLER = "0" }
        "--backup-media" { $env:WADDLE_BACKUP_MEDIA = "0" }
        "--backup-src" { $env:WADDLE_BACKUP_SRC = "0" }
        "--clean" { $env:WADDLE_CLEAN = "0" }
        "--drop-db" { $env:WADDLE_DROP_DB = "0" }
        "--keep-build-branch" { $env:WADDLE_KEEP_BUILD_BRANCH = "0" }
        "--remote" { $env:WADDLE_REMOTE = "0" }
    }
}

$env:WADDLE_BUILD_DIR = (Get-Location).Path + "\builder\" + $env:WADDLE_BUILD_TAG

Write-Host ""
Write-Host ""
Write-Host "[WADDLE NOTICE] Environment variables set."
Write-Host ""
Write-Host "========================================================================="
Write-Host "WADDLE_BUILD_TAG = $($env:WADDLE_BUILD_TAG)"
Write-Host ""
Write-Host "Unique name for git branch and build resource directory."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_ORIGINAL_BRANCH = $($env:WADDLE_ORIGINAL_BRANCH)"
Write-Host ""
Write-Host "Original branch before any git operations (for merge/restoration)."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_PLATFORM = $($env:WADDLE_PLATFORM)"
Write-Host ""
Write-Host "Website blueprint/platform used by this project."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_DB_NAME = $($env:WADDLE_DB_NAME)"
Write-Host ""
Write-Host "Website database name."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_WEBSITE_URL = $($env:WADDLE_WEBSITE_URL)"
Write-Host ""
Write-Host "Website URL."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_INSTALL_COMPOSER = $($env:WADDLE_INSTALL_COMPOSER)"
Write-Host ""
Write-Host "Whether to install Composer inside PHP guest system."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_INSTALL_PHPMYADMIN = $($env:WADDLE_INSTALL_PHPMYADMIN)"
Write-Host ""
Write-Host "Whether to install PhpMyAdmin."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_SSL = $($env:WADDLE_SSL)"
Write-Host ""
Write-Host "Whether to use SSL/TLS (https)."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_BACKUP_MEDIA = $($env:WADDLE_BACKUP_MEDIA)"
Write-Host ""
Write-Host "Whether to backup media directory (if any, depends on platform)."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_BACKUP_SRC = $($env:WADDLE_BACKUP_SRC)"
Write-Host ""
Write-Host "Whether to backup website source directory (for improved rollback stability)."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_CLEAN = $($env:WADDLE_CLEAN)"
Write-Host ""
Write-Host "Whether to delete build resource directory after building."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_RUN_PLATFORM_INSTALLER = $($env:WADDLE_RUN_PLATFORM_INSTALLER)"
Write-Host ""
Write-Host "Whether to run the platform installer script."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_DROP_DB = $($env:WADDLE_DROP_DB)"
Write-Host ""
Write-Host "Whether to replace the current database with a clean one."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_KEEP_BUILD_BRANCH = $($env:WADDLE_KEEP_BUILD_BRANCH)"
Write-Host ""
Write-Host "Whether to keep the git branch used while building, for history tracking."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_BUILD_DIR = $($env:WADDLE_BUILD_DIR)"
Write-Host ""
Write-Host "Absolute path to build tag directory."
Write-Host "-------------------------------------------------------------------------"
Write-Host "WADDLE_REMOTE = $($env:WADDLE_REMOTE)"
Write-Host ""
Write-Host "Set when running on a remote server (e.g. staging or production). Skips local-only steps such as docker image builds, SSL certificate generation, and git branch management."
Write-Host "-------------------------------------------------------------------------"
Write-Host ""
Write-Host ""

$env:WADDLE_ENV_PREPARED = "0"

# Validate required values possibly empty.
if ($env:WADDLE_PLATFORM -eq "") {
    Write-Host "[WADDLE ERROR] Platform is not set. Please specify it with --platform."
    exit 1
}

if ($env:WADDLE_DB_NAME -eq "") {
    Write-Host "[WADDLE ERROR] Database name is not set. Please specify it with --db-name."
    exit 1
}

if ($env:WADDLE_WEBSITE_URL -eq "") {
    Write-Host "[WADDLE ERROR] Website URL is not set. Please specify it with --url."
    exit 1
}

# Validate that original branch is not a build branch.
if ($env:WADDLE_ORIGINAL_BRANCH -and $env:WADDLE_ORIGINAL_BRANCH.StartsWith("waddle-build-")) {
    Write-Host "[WADDLE ERROR] Cannot use a build branch ($($env:WADDLE_ORIGINAL_BRANCH)) as the original branch."
    Write-Host "[WADDLE ERROR] Build branches are temporary and should not be used as your base branch."
    exit 1
}

# Concatenate arguments list for sub-commands.
$waddleArgs = @(
    "--build-tag", $env:WADDLE_BUILD_TAG,
    "--original-branch", $env:WADDLE_ORIGINAL_BRANCH,
    "--platform", $env:WADDLE_PLATFORM,
    "--db-name", $env:WADDLE_DB_NAME,
    "--url", $env:WADDLE_WEBSITE_URL
)

if ($env:WADDLE_SSL -eq "0") { $waddleArgs += "--ssl" }
if ($env:WADDLE_INSTALL_COMPOSER -eq "0") { $waddleArgs += "--install-composer" }
if ($env:WADDLE_INSTALL_PHPMYADMIN -eq "0") { $waddleArgs += "--install-phpmyadmin" }
if ($env:WADDLE_RUN_PLATFORM_INSTALLER -eq "0") { $waddleArgs += "--run-platform-installer" }
if ($env:WADDLE_BACKUP_MEDIA -eq "0") { $waddleArgs += "--backup-media" }
if ($env:WADDLE_BACKUP_SRC -eq "0") { $waddleArgs += "--backup-src" }
if ($env:WADDLE_CLEAN -eq "0") { $waddleArgs += "--clean" }
if ($env:WADDLE_DROP_DB -eq "0") { $waddleArgs += "--drop-db" }
if ($env:WADDLE_KEEP_BUILD_BRANCH -eq "0") { $waddleArgs += "--keep-build-branch" }
if ($env:WADDLE_REMOTE -eq "0") { $waddleArgs += "--remote" }

$env:WADDLE_ARGS = $waddleArgs -join " "
