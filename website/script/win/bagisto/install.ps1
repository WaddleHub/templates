$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download Bagisto via Composer.
Write-Host "[WADDLE] Downloading Bagisto version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project bagisto/bagisto:{{tags.website.version.full_raw}} `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Bagisto." }

# Apply configuration.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/bagisto/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Run the Bagisto installer. Its admin-creation prompts are built on Laravel Prompts, which
# requires a real TTY to read input. `docker compose exec -T` has none, so piped stdin is ignored
# and every prompt silently returns its hardcoded default (name "Example", email
# "admin@example.com", password "admin123") regardless of what is piped in. Skip admin creation
# here and set the real credentials directly afterward.
#
# 2.5 dropped every skip flag: --no-interaction now keeps the existing .env and creates the
# default admin, which is overwritten afterward anyway. 2.4.0 added --skip-github-star and 2.4.6
# --skip-cloud-promotion.
Write-Host "[WADDLE] Installing Bagisto."
{{#if (version_compare tags.website.version.raw '>=' '2.5.0')}}
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" bagisto:install --no-interaction{{#if public.website.deploy_sample_data}} --demo-samples{{/if}}
{{else}}
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" bagisto:install `
    --skip-env-check --skip-admin-creation{{#if (version_compare tags.website.version.raw '>=' '2.4.0')}} --skip-github-star{{/if}}{{#if (version_compare tags.website.version.raw '>=' '2.4.6')}} --skip-cloud-promotion{{/if}}
{{/if}}
if ($LASTEXITCODE -ne 0) { throw "Failed to install Bagisto." }

# Configure the admin account with the real credentials.
Write-Host "[WADDLE] Configuring admin account."
@'
<?php
$dsn = 'mysql:host=db;port=3306;dbname={{public.website.db_name}};charset=utf8mb4';
$pdo = new PDO($dsn, getenv('WADDLE_DB_USER'), getenv('WADDLE_DB_PASSWORD'), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$name     = '{{public.website.admin_firstname}} {{public.website.admin_lastname}}';
$email    = '{{public.website.admin_email}}';
$password = password_hash(getenv('WADDLE_ADMIN_PASSWORD'), PASSWORD_BCRYPT, ['cost' => 12]);

$pdo->prepare('UPDATE admins SET name = ?, email = ?, password = ? WHERE id = 1')
    ->execute([$name, $email, $password]);

echo "[WADDLE] Admin account configured.\n";
'@ | docker compose exec -i -e WADDLE_ADMIN_PASSWORD="$env:WADDLE_ADMIN_PASSWORD" php php
if ($LASTEXITCODE -ne 0) { throw "Failed to configure the admin account." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
