#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download Krayin CRM via Composer.
echo "[WADDLE] Downloading Krayin CRM version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project \
    krayin/laravel-crm:{{tags.website.version.full_raw}} "{{project_path 'website/src'}}" --no-interaction

# Apply Waddle configuration.
echo "[WADDLE] Applying configuration."
cp "./website/conf/krayin/.env" "./website/src/.env"

# Run the Krayin CRM installer. Its admin-creation prompts are built on Laravel Prompts, which
# requires a real TTY to read input. `docker compose exec -T` has none, so piped stdin is ignored
# and every prompt silently returns its hardcoded default (name "Example", email
# "admin@example.com", password "admin123") regardless of what is piped in. Skip admin creation
# here and set the real credentials directly afterward.
echo "[WADDLE] Installing Krayin CRM."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" krayin-crm:install \
    --skip-env-check --skip-admin-creation

# Configure the admin account with the real credentials (see note above).
echo "[WADDLE] Configuring admin account."
cat > "./website/src/.waddle_admin_setup.php" << 'PHP'
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
PHP
docker compose exec -T -e WADDLE_ADMIN_PASSWORD="${WADDLE_ADMIN_PASSWORD}" php php "{{project_path 'website/src'}}/.waddle_admin_setup.php"
rm -f "./website/src/.waddle_admin_setup.php"

# Publish assets and clear caches.
echo "[WADDLE] Publishing assets."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" vendor:publish --all --force

echo "[WADDLE] Clearing caches."
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize:clear
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" optimize

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
