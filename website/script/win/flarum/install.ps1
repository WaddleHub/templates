$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download Flarum via Composer.
Write-Host "[WADDLE] Downloading Flarum version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project flarum/flarum:{{tags.website.version.full_raw}} `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Flarum." }

# Copy install configuration.
Write-Host "[WADDLE] Copying install configuration."
docker compose exec -T php cp "{{project_path 'website/conf/flarum/install.yml'}}" "{{project_path 'website/src'}}/install.yml"
if ($LASTEXITCODE -ne 0) { throw "Failed to copy install configuration." }

# Run the Flarum CLI installer.
Write-Host "[WADDLE] Running Flarum installer."
docker compose exec -T php php "{{project_path 'website/src'}}/flarum" install `
    --file="{{project_path 'website/src'}}/install.yml"
if ($LASTEXITCODE -ne 0) { throw "Failed to run the Flarum installer." }

# Remove temporary install config.
docker compose exec -T php rm -f "{{project_path 'website/src'}}/install.yml"

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
