$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

$phpbbSrcContainer = "{{project_path 'website/src'}}/phpBB"

# Clone the phpBB repository and install its PHP dependencies, from inside the php container for
# accurate permissions. The actual web files live in the phpBB/ subdirectory.
# Afterwards, drop the git metadata, so the project's repository tracks website/src as plain files.
Write-Host "[WADDLE] Downloading phpBB version {{tags.website.version.full_raw}}."
$installScript = @'
set -eux
git clone --depth=1 --branch={{tags.website.version.full_raw}} https://github.com/phpbb/phpbb.git "{{project_path 'website/src'}}"
composer install --no-dev --working-dir="{{project_path 'website/src'}}/phpBB"
find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +
'@
$installScript | docker compose exec -i php sh -c "tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to download phpBB." }

# Copy install configuration.
Write-Host "[WADDLE] Copying install configuration."
docker compose exec -T php cp "{{project_path 'website/conf/phpbb/install.yml'}}" "$phpbbSrcContainer/install.yml"
if ($LASTEXITCODE -ne 0) { throw "Failed to copy install configuration." }

# Run the phpBB CLI installer.
Write-Host "[WADDLE] Running phpBB CLI installer."
docker compose exec -T php sh -c `
    "cd '$phpbbSrcContainer' && php install/phpbbcli.php install install.yml"
if ($LASTEXITCODE -ne 0) { throw "Failed to run the phpBB installer." }

# Remove temporary install config and the install directory.
Write-Host "[WADDLE] Removing install directory."
docker compose exec -T php sh -c "rm -f '$phpbbSrcContainer/install.yml' && rm -rf '$phpbbSrcContainer/install'"

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
