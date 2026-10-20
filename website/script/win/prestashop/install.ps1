$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download and extract PrestaShop source, then run Composer and build the NPM assets, from inside
# the php container for accurate permissions.
Write-Host "[WADDLE] Downloading source."
$installScript = @'
set -eux
curl -L --retry 3 --retry-delay 5 {{tags.website.tar}} -o /tmp/prestashop.tar.gz
tar -C "{{project_path 'website/src'}}" -xzf /tmp/prestashop.tar.gz --strip-components=1
rm -f /tmp/prestashop.tar.gz
composer install --working-dir="{{project_path 'website/src'}}"
(cd "{{project_path 'website/src'}}" && make assets)
'@
# PowerShell adds a UTF-8 BOM and CRLF line endings to the script it pipes in. Strip both, the BOM
# would turn "set -eux" into an unknown command and silently disable error checking.
$installScript | docker compose exec -i php sh -c "sed '1s/^\xef\xbb\xbf//' | tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to build source." }

# CLI installer may be in install-dev or install directory.
$installerName = (docker compose exec -T php sh -c "if [ -f '{{project_path 'website/src'}}/install-dev/index_cli.php' ]; then echo install-dev; elif [ -f '{{project_path 'website/src'}}/install/index_cli.php' ]; then echo install; fi").Trim()

if (-not $installerName) {
    Write-Host "[Website installer] Failed to find CLI installer."
    exit 1
}

# Clear Symfony DI container cache shipped with the PS source before running the installer.
# The pre-built cache has hardcoded DB settings that cause connection failures via socket.
docker compose exec -T php rm -rf "{{project_path 'website/src'}}/var/cache/"

docker compose exec -T php php "{{project_path 'website/src'}}/$installerName/index_cli.php" `
    --title="{{public.website.title}}" `
    --email="{{public.website.admin_email}}" `
    --password="$env:WADDLE_ADMIN_PASSWORD" `
    --firstname="{{public.website.admin_firstname}}" `
    --lastname="{{public.website.admin_lastname}}" `
    --domain={{public.website.url}} `
    --db_server=db `
    --db_name={{public.website.db_name}} `
    --db_user="$env:WADDLE_DB_USER" `
    --db_password="$env:WADDLE_DB_PASSWORD" `
    --db_clear=1 `
    --language="{{public.website.language}}" `
    --timezone={{timezone}} `
    --newsletter=0{{#if ssl.enabled}} --ssl=1{{/if}} | Tee-Object -Variable installOutput

# Check for successful installation. The exit code of docker compose exec isn't reliable here, so
# look for the installer's own success message instead.
if (-not ($installOutput | Select-String -Pattern "Installation successful" -Quiet)) {
    throw "PrestaShop installation failed. See output above."
}

# The installer runs Symfony's `assets:install --symlink` against the admin folder, creating
# symlinks from inside the container directly on this Docker bind mount. Docker Desktop's Windows
# file-sharing layer translates that `symlink()` call into a non-standard NTFS reparse point that
# native Windows tools (including git, via the MSYS2 runtime `bin/deploy/run.ps1` later uses to
# stage the build) cannot read, failing with "Function not implemented". Replace every such
# symlink with a real recursive copy of its target, done from inside the container using normal
# POSIX `readlink`/`cp` so no reparse point is ever exposed on the Windows side.
$symlinkFixScript = @'
set -eux
find "{{project_path 'website/src'}}" -type l | while read -r link; do
    target=$(readlink -f "$link")
    rm -f "$link"
    cp -a "$target" "$link"
done
'@
$symlinkFixScript | docker compose exec -i php sh -c "sed '1s/^\xef\xbb\xbf//' | tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to replace container-created symlinks with real copies." }

# Remove the installer now that it's done.
docker compose exec -T php rm -rf "{{project_path 'website/src'}}/$installerName"
if ($LASTEXITCODE -ne 0) { throw "Failed to remove the installer." }

# Remove docker-compose.yml if it exists, to avoid conflicts with the one produced by Waddle.
docker compose exec -T php rm -f "{{project_path 'website/src'}}/docker-compose.yml"

# Set admin panel URI if specified. The shipped admin directory is named to match the CLI
# installer directory found above: "admin-dev" alongside "install-dev", or "admin" alongside
# "install".
{{#if (not_empty public.website.admin_route)}}
$adminDir = (docker compose exec -T php sh -c "if [ -d '{{project_path 'website/src'}}/admin-dev' ]; then echo admin-dev; elif [ -d '{{project_path 'website/src'}}/admin' ]; then echo admin; fi").Trim()

if ($adminDir -and $adminDir -ne "{{public.website.admin_route}}") {
    Write-Host "[Website installer] Setting admin panel URI to {{public.website.admin_route}}"
    docker compose exec -T php mv "{{project_path 'website/src'}}/$adminDir" "{{project_path 'website/src'}}/{{public.website.admin_route}}"
    if ($LASTEXITCODE -ne 0) { throw "Failed to set admin panel URI." }
}
{{/if}}

# The default theme's asset cache doesn't ship in the download at all, CccReducer creates it
# lazily on the theme's first page render, unlike the rest of the daemon-owned list below, which
# ships as empty placeholder directories the chown can act on directly.
docker compose exec -T php mkdir -p "{{project_path 'website/src'}}/themes/hummingbird/assets/cache"
if ($LASTEXITCODE -ne 0) { throw "Failed to create theme asset cache directory." }

# Execute custom PHP script to configure mail (SMTP to the `mail` service). See script for details.
Write-Host "[WADDLE] Configuring mail."
docker compose exec -T php php "{{project_path 'website/conf/prestashop/configure-mail.php'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to configure mail." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
