$ErrorActionPreference = "Stop"

# Text piped into native commands (the installers' `@'...'@ | docker compose exec -i ...`) is
# encoded with $OutputEncoding, which Windows PowerShell 5.1 sets to ASCII. UTF-8 without a BOM
# is used instead. The installers run from tthis script, so they inherit it.
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

. ./bin/deploy/set-env.ps1 @args

if (-not (Test-Path "./builder/$($env:WADDLE_BUILD_TAG)" -PathType Container)) {
    New-Item -Path "./builder/$($env:WADDLE_BUILD_TAG)" -ItemType Directory -Force | Out-Null
}

# Some platforms (e.g. Magento's vendor/test fixture trees) have paths deep enough to exceed
# Windows' legacy MAX_PATH.
git config core.longpaths true
if ($LASTEXITCODE -ne 0) { throw "Failed to enable core.longpaths." }

# Ensures a Docker Compose service is running, starting or unpausing it if needed.
#
# Returns $true if the service is up after the call, $false if the service is not configured or
# does not stay running.
function EnsureServiceUp {
    param (
        [string]$serviceName
    )

    if (-not (IsServiceConfigured $serviceName)) {
        return $false
    }

    if (docker compose ps --services $serviceName --status paused) {
        docker compose unpause $serviceName | Out-Null
        return $true
    }

    if (docker compose ps --services $serviceName --status exited) {
        docker compose up -d $serviceName | Out-Null

        # `docker compose up -d` only confirms the start command was accepted, not that the
        # container stayed up. A service restarting from a broken state (e.g. a database whose
        # data directory never finished initializing) can crash again within moments. Wait
        # for the service to come up before proceeding.
        $checkCount = 5

        while ($checkCount -ne 0 -and -not (docker compose ps --services $serviceName --status running)) {
            $checkCount -= 1
            Start-Sleep -Seconds 1
        }

        if (docker compose ps --services $serviceName --status running) {
            return $true
        }

        return $false
    }

    if (docker compose ps --services $serviceName --status running) {
        return $true
    }

    return $false
}

# Check if a Docker Compose service is configured.
function IsServiceConfigured {
    param (
        [string]$serviceName
    )

    if (-not $serviceName) {
        return $false
    }

    return ((docker compose config --services) -contains $serviceName)
}

# Build a service image, only on local environments, we push pre-built images to remotes.
function BuildService {
    param (
        [string]$serviceName
    )

    if ($env:WADDLE_REMOTE -ne "0") {
        docker compose build $serviceName
        if ($LASTEXITCODE -ne 0) { throw "Failed to build $serviceName service." }
    }
}

Write-Host "[WADDLE NOTICE] Starting deployment."

# Ensure our environment is prepared for deployment.
if ($env:WADDLE_ENV_PREPARED -ne "0") {
    Write-Host "[WADDLE ERROR] Environment not prepared, aborting."
    exit 1
}

# Original branch is resolved by set-env script.
# It must be captured before any git operations (like checking out build branch).
Write-Host "[WADDLE] Original branch: $($env:WADDLE_ORIGINAL_BRANCH)"

if (-not $env:WADDLE_ORIGINAL_BRANCH) {
    Write-Host "[WADDLE ERROR] Original branch not set. This should be set by set-env script."
    exit 1
}

# Waddle itself backs up what a rollback needs before it renders the templates (the running
# services, the gitignored files in builder/<tag>/stash.tar.gz, and which service data
# directories exist), since the render rewrites gitignored files. The services are only recorded
# here when the script is run by hand.
if (-not (Test-Path "./builder/$($env:WADDLE_BUILD_TAG)/services.txt" -PathType Leaf)) {
    ((docker compose ps --services) -join " ") | Set-Content -Path "./builder/$($env:WADDLE_BUILD_TAG)/services.txt" -NoNewline
}

if ($env:WADDLE_BUILD_TAG -ne (git branch --show-current)) {
    Write-Host "[WADDLE] Creating build tag."
    # Runs inside the WSL2 distro, so executable bits are recorded (see set-env.ps1).
    Invoke-DistroGit checkout -b $env:WADDLE_BUILD_TAG
    if ($LASTEXITCODE -ne 0) { throw "Failed to create the build tag branch." }
    Invoke-DistroGit add -A
    if ($LASTEXITCODE -ne 0) { throw "Failed to stage files on the build tag branch." }
    Invoke-DistroGit commit --allow-empty -m "$($env:WADDLE_BUILD_TAG)-start"
    if ($LASTEXITCODE -ne 0) { throw "Failed to commit the build tag branch." }
}

# Clear Redis cache.
if (EnsureServiceUp "redis") {
    Write-Host "[WADDLE] Flushing redis cache"
    docker compose exec -T redis redis-cli FLUSHALL
    if ($LASTEXITCODE -ne 0) { throw "Failed to flush Redis cache." }
}

# Snapshot the database before taking containers down.
# This must happen while the old container is still running on the old image, so the
# dump is schema-compatible with that image and a rollback can cleanly restore to it.
# Skipped on first build when no DB container exists yet.
if (EnsureServiceUp "db") {
    Write-Host "[WADDLE] Backing up databases."
    # The dump is written inside the container onto the mariadb bind mount, then moved. Capturing
    # its output here instead would garble every non-ASCII character since PowerShell decodes a
    # native command's output with the console code page (e.g. CP437).
    $sqlPath = "./builder/$($env:WADDLE_BUILD_TAG)/db.sql"
    docker compose exec -u 0 -T db sh "{{project_path 'mariadb/script/backup.sh'}}" "{{project_path 'mariadb'}}/.waddle_backup.sql"
    if ($LASTEXITCODE -ne 0) { throw "Failed to back up databases." }
    Move-Item -Force "./mariadb/.waddle_backup.sql" $sqlPath
    & "$env:SystemRoot\System32\tar.exe" -C "./builder/$($env:WADDLE_BUILD_TAG)" -czf "./builder/$($env:WADDLE_BUILD_TAG)/db.tar.gz" db.sql
    if ($LASTEXITCODE -ne 0) { throw "Failed to archive database backup." }
    Remove-Item "./builder/$($env:WADDLE_BUILD_TAG)/db.sql"
}

# Stop running containers.
Write-Host "[WADDLE] Stopping running containers."
docker compose down -v

# Generate SSL certificates.
#
# Certs are named after the project directory rather than the website URL, so the filename stays
# stable across URL changes and can't collide with another project using the same URL.
if ($env:WADDLE_REMOTE -ne "0" -and $env:WADDLE_SSL -eq "0" -and $env:WADDLE_WEBSITE_URL -and (Get-Command mkcert -ErrorAction SilentlyContinue)) {
    Write-Host "[WADDLE] Generating SSL certificates."

    if (-not (Test-Path "./ssl" -PathType Container)) {
        New-Item -Path "./ssl" -ItemType Directory | Out-Null
    }

    mkcert -cert-file "./ssl/{{ssl.cert_name}}.crt" -key-file "./ssl/{{ssl.cert_name}}.key" "$($env:WADDLE_WEBSITE_URL)" "*.$($env:WADDLE_WEBSITE_URL)"
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate SSL certificates." }
}

# Build OpenSearch service.
if (IsServiceConfigured "opensearch") {
    Write-Host "[WADDLE OPENSEARCH START]"
    Write-Host "[WADDLE] Building OpenSearch service (opensearch)."

    BuildService opensearch
    docker compose up -d opensearch
    if ($LASTEXITCODE -ne 0) { throw "Failed to start OpenSearch service." }

    if (-not (EnsureServiceUp "opensearch")) {
        Write-Host "[WADDLE] OpenSearch service (opensearch) failed to start."
        exit 1
    }

    Write-Host "[WADDLE OPENSEARCH END]"
}

# Build Redis service.
if (IsServiceConfigured "redis") {
    Write-Host "[WADDLE REDIS START]"
    Write-Host "[WADDLE] Building Redis service (redis)."

    BuildService redis
    docker compose up -d redis
    if ($LASTEXITCODE -ne 0) { throw "Failed to start Redis service." }

    if (-not (EnsureServiceUp "redis")) {
        Write-Host "[WADDLE ERROR] Redis service (redis) failed to start."
        exit 1
    }

    Write-Host "[WADDLE] Executing init script inside Redis container."
    docker compose exec -T redis "{{project_path 'redis/script/init.sh'}}"
    if ($LASTEXITCODE -ne 0) { throw "Failed to execute Redis init script." }

    Write-Host "[WADDLE REDIS END]"
}

# Build MailCatcher service.
if (IsServiceConfigured "mail") {
    Write-Host "[WADDLE MAILCATCHER START]"
    Write-Host "[WADDLE] Building MailCatcher service (mail)."

    BuildService mail
    docker compose up -d mail
    if ($LASTEXITCODE -ne 0) { throw "Failed to start MailCatcher service." }

    if (-not (EnsureServiceUp "mail")) {
        Write-Host "[WADDLE ERROR] MailCatcher service (mail) failed to start."
        exit 1
    }

    Write-Host "[WADDLE MAILCATCHER END]"
}

# Build MariaDB service.
if (IsServiceConfigured "db") {
    Write-Host "[WADDLE MARIADB START]"
    Write-Host "[WADDLE] Building database service (db)."

    BuildService db

    # init.sh is self-guarding, it checks for an existing data directory and skips
    # initialisation if one is found.
    Write-Host "[WADDLE] Executing init script inside database container."
    docker compose run --rm db "{{project_path 'mariadb/script/init.sh'}}"
    if ($LASTEXITCODE -ne 0) { throw "Failed to execute database init script." }

    Write-Host "[WADDLE] Starting database container."
    docker compose up -d db
    if ($LASTEXITCODE -ne 0) { throw "Failed to start database service." }

    if (-not (EnsureServiceUp "db")) {
        Write-Host "[WADDLE ERROR] Database service (db) failed to start."
        exit 1
    }

    # Wait for mysqld service to start inside container.
    $waitCount = 60

    while ($waitCount -ne 0) {
        # mysqladmin writes a deprecation notice to stderr even on success. Under
        # $ErrorActionPreference = "Stop", redirecting a native command's stderr (even to $null)
        # still converts it into a terminating NativeCommandError, so the preference is relaxed
        # for the duration of this call rather than relying on the redirect alone.
        $ErrorActionPreference = "SilentlyContinue"
        $pingOutput = docker compose exec -u 0 -T db mysqladmin ping 2>$null
        $ErrorActionPreference = "Stop"

        if ($pingOutput) {
            break
        }

        Write-Host "[WADDLE] Waiting for mysqld..."
        $waitCount--
        Start-Sleep -Seconds 1
    }

    if ($waitCount -eq 0) {
        Write-Host "[WADDLE ERROR] Database service (db) failed to start. MySQL daemon never came alive."
        exit 1
    }

    # Drop current database.
    if ($env:WADDLE_REMOTE -ne "0" -and $env:WADDLE_DB_NAME -and $env:WADDLE_DROP_DB -eq "0") {
        Write-Host "[WADDLE] Dropping database $($env:WADDLE_DB_NAME)."
        docker compose exec -u 0 -T db mariadb -e "DROP DATABASE IF EXISTS $($env:WADDLE_DB_NAME)"
        if ($LASTEXITCODE -ne 0) { throw "Failed to drop database $($env:WADDLE_DB_NAME)." }
    }

    # setup.sh is idempotent (CREATE DATABASE/USER IF NOT EXISTS) and runs mariadb-upgrade
    # to update system tables after a version change.
    Write-Host "[WADDLE] Executing setup script inside database container."
    docker compose exec -u 0 -T db "{{project_path 'mariadb/script/setup.sh'}}"
    if ($LASTEXITCODE -ne 0) { throw "Failed to execute database setup script." }

    # Import the database supplied when the project was cloned (local only), before the website
    # installer runs. Read from the mariadb bind mount, never piped through PowerShell, which would
    # garble non-ASCII characters. Waddle removes it once the build has succeeded, so a build
    # failing after the import, once rolled back, imports it again.
    if ($env:WADDLE_REMOTE -ne "0" -and (Test-Path "./builder/clone-database.sql" -PathType Leaf) -and $env:WADDLE_DB_NAME) {
        Write-Host "[WADDLE] Importing the supplied database into $($env:WADDLE_DB_NAME)."
        Move-Item "./builder/clone-database.sql" "./mariadb/.waddle_import.sql"
        try {
            docker compose exec -u 0 -T db sh -c "mariadb $($env:WADDLE_DB_NAME) < {{project_path 'mariadb'}}/.waddle_import.sql"
            if ($LASTEXITCODE -ne 0) { throw "Failed to import the supplied database." }
        } finally {
            Move-Item "./mariadb/.waddle_import.sql" "./builder/clone-database.sql"
        }
    }

    Write-Host "[WADDLE MARIADB END]"
}

# Build Node service.
if (IsServiceConfigured "node") {
    Write-Host "[WADDLE NODE START]"
    Write-Host "[WADDLE] Building Node service (node)."

    BuildService node
    docker compose up -d node
    if ($LASTEXITCODE -ne 0) { throw "Failed to start Node service." }

# If Node is the runtime, the container must stay up (idling until the platform installer
# has put the website in place, on a first build). Otherwise, only a failed exit counts
# (a running container reports exit code 0 as well).
{{#if (is_equal (get_platform_runtime public.website.platform) 'node')}}
    if (-not (EnsureServiceUp "node")) {
        Write-Host "[WADDLE ERROR] Node service (node) failed to start."
        exit 1
    }
{{else}}
    $nodeState = docker compose ps -a --format json node | Out-String
    if ($nodeState -notmatch '"ExitCode":0,') {
        Write-Host "[WADDLE ERROR] Node service (node) failed to start."
        exit 1
    }
{{/if}}

    # Build Node cron service.
    if (IsServiceConfigured "node-cron") {
        Write-Host "[WADDLE] Building Node cron service (node-cron)."
        BuildService node-cron
        docker compose up -d node-cron
        if ($LASTEXITCODE -ne 0) { throw "Failed to start Node cron service." }

        if (-not (EnsureServiceUp "node-cron")) {
            Write-Host "[WADDLE ERROR] Node cron service (node-cron) failed to start."
            exit 1
        }
    }

    Write-Host "[WADDLE NODE END]"
}

# Build PHP service.
if (IsServiceConfigured "php") {
    Write-Host "[WADDLE PHP START]"
    Write-Host "[WADDLE] Building PHP service (php)."

    BuildService php
    docker compose up -d php
    if ($LASTEXITCODE -ne 0) { throw "Failed to start PHP service." }

    if (-not (EnsureServiceUp "php")) {
        Write-Host "[WADDLE ERROR] PHP service (php) failed to start."
        exit 1
    }

    # Install Composer.
    if ($env:WADDLE_INSTALL_COMPOSER -eq "0") {
        Write-Host "[WADDLE] Installing Composer."
        docker compose exec -T php "{{project_path 'composer/script/install.sh'}}"
        if ($LASTEXITCODE -ne 0) { throw "Failed to install Composer." }

        # Install the website's Composer dependencies when its source is there without them (local
        # only). Most platforms' own .gitignore leaves vendor/ out, so a clone of an installed
        # website has a composer.json and composer.lock but no vendor/. A fresh install has no
        # source yet, and an installed website already has vendor/, so neither is affected.
        if ($env:WADDLE_REMOTE -ne "0" -and (Test-Path "./website/src/composer.json" -PathType Leaf) -and -not (Test-Path "./website/src/vendor" -PathType Container)) {
            Write-Host "[WADDLE] Installing the website's Composer dependencies."
            docker compose exec -T php composer install --no-interaction --working-dir="{{project_path 'website/src'}}"
            if ($LASTEXITCODE -ne 0) { throw "Failed to install the website's Composer dependencies." }
        }
    }

    # Install PhpMyAdmin.
    if ($env:WADDLE_REMOTE -ne "0" -and $env:WADDLE_INSTALL_PHPMYADMIN -eq "0") {
        Write-Host "[WADDLE] Installing PhpMyAdmin."
        docker compose exec -T php "{{project_path 'phpmyadmin/script/install.sh'}}"
        if ($LASTEXITCODE -ne 0) { throw "Failed to install PhpMyAdmin." }
    }

    # Build PHP cron service.
    if (IsServiceConfigured "php-cron") {
        Write-Host "[WADDLE] Building PHP cron service (php-cron)."

        BuildService php-cron
        docker compose up -d php-cron
        if ($LASTEXITCODE -ne 0) { throw "Failed to start PHP cron service." }

        if (-not (EnsureServiceUp "php-cron")) {
            Write-Host "[WADDLE ERROR] PHP cron service (php-cron) failed to start."
            exit 1
        }
    }

    Write-Host "[WADDLE PHP END]"
}

# Stop cron containers before the platform installer runs to prevent scheduled jobs
# from firing against an application in a mid-install state.
if (EnsureServiceUp "php-cron") {
    Write-Host "[WADDLE] Stopping PHP cron container."
    docker compose stop php-cron
    if ($LASTEXITCODE -ne 0) { throw "Failed to stop PHP cron container." }
}

if (EnsureServiceUp "node-cron") {
    Write-Host "[WADDLE] Stopping Node cron container."
    docker compose stop node-cron
    if ($LASTEXITCODE -ne 0) { throw "Failed to stop Node cron container." }
}

# Install / update website source.
if ($env:WADDLE_REMOTE -ne "0" -and $env:WADDLE_RUN_PLATFORM_INSTALLER -eq "0") {
    Write-Host "[WADDLE WEBSITE START]"

    $installerScript = "./website/script/win/$($env:WADDLE_PLATFORM)/installer.ps1"

    if (Test-Path $installerScript -PathType Leaf) {
        {{#if public.php.install}}
        if (-not (EnsureServiceUp "php")) {
            Write-Host "[WADDLE ERROR] PHP service (php) is not running. Failed to execute website installer."
            exit 1
        }
        {{/if}}
        {{#if (is_equal (get_platform_runtime public.website.platform) 'node')}}
        if (-not (EnsureServiceUp "node")) {
            Write-Host "[WADDLE ERROR] Node service (node) is not running. Failed to execute website installer."
            exit 1
        }
        {{/if}}

        Write-Host "[WADDLE] Executing website installer script."
        & $installerScript ($env:WADDLE_ARGS -split ' ')
    } else {
        Write-Host "[WADDLE] No installer script found for platform $($env:WADDLE_PLATFORM), skipping."
    }

    Write-Host "[WADDLE WEBSITE END]"
}

# Build Nginx service.
if (IsServiceConfigured "web") {
    Write-Host "[WADDLE NGINX START]"
    Write-Host "[WADDLE] Building Nginx service (web)."
    BuildService web
    docker compose up -d web
    if ($LASTEXITCODE -ne 0) { throw "Failed to start Nginx service." }

    if (-not (EnsureServiceUp "web")) {
        Write-Host "[WADDLE ERROR] Nginx service (web) failed to start."
        exit 1
    }
    Write-Host "[WADDLE NGINX END]"
}

# Commit after completing the process and merge back to original branch.
Write-Host "[WADDLE] Committing updates and merging $($env:WADDLE_BUILD_TAG) into $($env:WADDLE_ORIGINAL_BRANCH)."

# Commit, checkout and merge run inside the WSL2 distro, so executable bits survive into the
# repository and the working tree (see set-env.ps1). If staging fails, nothing is committed.
Invoke-DistroGit add -A

if ($LASTEXITCODE -eq 0) {
    Invoke-DistroGit commit --allow-empty -m "$($env:WADDLE_BUILD_TAG)-complete"
    if ($LASTEXITCODE -ne 0) { throw "Failed to commit the build branch." }
    Invoke-DistroGit checkout $env:WADDLE_ORIGINAL_BRANCH
    if ($LASTEXITCODE -ne 0) { throw "Failed to checkout $($env:WADDLE_ORIGINAL_BRANCH)." }
    Invoke-DistroGit merge $env:WADDLE_BUILD_TAG
    if ($LASTEXITCODE -ne 0) { throw "Failed to merge the build branch." }

    if ($env:WADDLE_KEEP_BUILD_BRANCH -ne "0") {
        git branch -D $env:WADDLE_BUILD_TAG
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete the build branch." }
    }

    # Recreate running containers after merge to ensure they are stable (since checking out
    # the original branch will cause some files to disappear briefly from the filesystem
    # which can break some service containers). A plain restart is not enough (it can fail
    # on missing bind mounts), the containers must be recreated.
    if (EnsureServiceUp "php") {
        Write-Host "[WADDLE] Recreating PHP after merge."
        docker compose up -d --force-recreate --no-deps php
        if ($LASTEXITCODE -ne 0) { throw "Failed to recreate PHP after merge." }
    }

    if (EnsureServiceUp "node") {
        Write-Host "[WADDLE] Recreating Node after merge."
        docker compose up -d --force-recreate --no-deps node
        if ($LASTEXITCODE -ne 0) { throw "Failed to recreate Node after merge." }
    }
} else {
    # The build itself succeeded (services are up), but the working tree is left
    # uncommitted on the build branch so no data is lost or silently discarded. The
    # original branch is intentionally left un-merged since resolving that automatically
    # over a dirty tree could conflict or drop changes.
    Write-Host "[WADDLE NOTICE] Failed to add files to git repository."
    Write-Host "[WADDLE NOTICE] Changes remain uncommitted on branch $($env:WADDLE_BUILD_TAG). Resolve the staging problem, then commit them, checkout $($env:WADDLE_ORIGINAL_BRANCH) and merge $($env:WADDLE_BUILD_TAG) into it. Run git inside your WSL distro (wsl.exe), not Git for Windows, so executable bits are kept."
}

# Start cron containers again. They were stopped, not removed, before the website step, so a
# plain start would reuse their bind mounts, which can be stale after the merge. Recreate them
# instead to ensure all is stable.
foreach ($cronService in @("php-cron", "node-cron")) {
    if (IsServiceConfigured $cronService) {
        docker compose up -d --force-recreate --no-deps $cronService | Out-Null
    }
}

if (-not (EnsureServiceUp "php-cron")) {
    Write-Host "[WADDLE] PHP cron container is not available."
}

if (-not (EnsureServiceUp "node-cron")) {
    Write-Host "[WADDLE] Node cron container is not available."
}

if ($env:WADDLE_CLEAN -eq "0" -and $env:WADDLE_BUILD_TAG) {
    Write-Host "[WADDLE] Cleaning up."
    Remove-Item -Recurse -Force "./builder/$($env:WADDLE_BUILD_TAG)"
}
