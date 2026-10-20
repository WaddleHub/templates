$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download Krayin CRM via Composer.
Write-Host "[WADDLE] Downloading Krayin CRM version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project krayin/laravel-crm:{{tags.website.version.full_raw}} `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download Krayin CRM." }

# Apply Waddle configuration.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/krayin/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Run the Krayin CRM installer. Its admin-creation prompts are built on Laravel Prompts, which
# requires a real TTY to read input. `docker compose exec -T` has none, so piped stdin is ignored
# and every prompt silently returns its hardcoded default (name "Example", email
# "admin@example.com", password "admin123") regardless of what is piped in. Skip admin creation
# here and set the real credentials directly afterward.
Write-Host "[WADDLE] Installing Krayin CRM."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" krayin-crm:install `
    --skip-env-check --skip-admin-creation
if ($LASTEXITCODE -ne 0) { throw "Failed to install Krayin CRM." }

# Configure the admin account with the real credentials (see note above).
Write-Host "[WADDLE] Configuring admin account."
@'
<?php
$dsn = 'mysql:host=db;port=3306;dbname={{public.website.db_name}};charset=utf8mb4';
$pdo = new PDO($dsn, getenv('WADDLE_DB_USER'), getenv('WADDLE_DB_PASSWORD'), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

$name     = '{{public.website.admin_firstname}} {{public.website.admin_lastname}}';
$email    = '{{public.website.admin_email}}';
$password = password_hash(getenv('WADDLE_ADMIN_PASSWORD'), PASSWORD_BCRYPT, ['cost' => 10]);

$pdo->prepare(
    'INSERT INTO users (id, name, email, password, role_id, status, created_at, updated_at) '
    .'VALUES (1, ?, ?, ?, 1, 1, NOW(), NOW()) '
    .'ON DUPLICATE KEY UPDATE name = VALUES(name), email = VALUES(email), password = VALUES(password)'
)->execute([$name, $email, $password]);

echo "[WADDLE] Admin account configured.\n";
'@ | docker compose exec -i -e WADDLE_ADMIN_PASSWORD="$env:WADDLE_ADMIN_PASSWORD" php php
if ($LASTEXITCODE -ne 0) { throw "Failed to configure the admin account." }

# Publish assets and clear caches.
Write-Host "[WADDLE] Publishing assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" vendor:publish --all --force
if ($LASTEXITCODE -ne 0) { throw "Failed to publish assets." }

Write-Host "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize:clear
if ($LASTEXITCODE -ne 0) { throw "Failed to clear caches." }
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize
if ($LASTEXITCODE -ne 0) { throw "Failed to optimize." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
