$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

Write-Host "[WADDLE] Downloading Yii3."
docker compose exec -T php composer create-project --prefer-dist yiisoft/app `
    "{{project_path 'website/src'}}" "{{tags.website.version.major}}.{{tags.website.version.minor}}.*" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Yii3." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
