$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

Write-Host "[WADDLE] Downloading CodeIgniter."
docker compose exec -T php composer create-project codeigniter4/appstarter `
    "{{project_path 'website/src'}}" "{{tags.website.version.major}}.{{tags.website.version.minor}}.*" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download CodeIgniter." }

# Apply configuration from website/conf/codeigniter/.env
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/codeigniter/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
