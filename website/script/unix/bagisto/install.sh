#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download Bagisto via Composer.
echo "[WADDLE] Downloading Bagisto version {{tags.website.version.full_raw}}."
docker compose exec -T php composer create-project \
    bagisto/bagisto:{{tags.website.version.full_raw}} "{{project_path 'website/src'}}" --no-interaction

# Apply Waddle configuration.
echo "[WADDLE] Applying configuration."
cp "./website/conf/bagisto/.env" "./website/src/.env"

# Run the Bagisto installer. Its admin-creation prompts are built on Laravel Prompts, which
# requires a real TTY to read input. `docker compose exec -T` has none, so piped stdin is ignored
# and every prompt silently returns its hardcoded default (name "Example", email
# "admin@example.com", password "admin123") regardless of what is piped in. Skip admin creation
# here and set the real credentials directly afterward.
#
# 2.5 dropped every skip flag: --no-interaction now keeps the existing .env and creates the
# default admin, which is overwritten afterward anyway. 2.4.0 added --skip-github-star and 2.4.6
# --skip-cloud-promotion.
echo "[WADDLE] Installing Bagisto."
{{#if (version_compare tags.website.version.raw '>=' '2.5.0')}}
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" bagisto:install --no-interaction
{{else}}
docker compose exec -T php php "{{project_path 'website/src'}}/artisan" bagisto:install \
    --skip-env-check --skip-admin-creation{{#if (version_compare tags.website.version.raw '>=' '2.4.0')}} --skip-github-star{{/if}}{{#if (version_compare tags.website.version.raw '>=' '2.4.6')}} --skip-cloud-promotion{{/if}}
{{/if}}

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
$password = password_hash(getenv('WADDLE_ADMIN_PASSWORD'), PASSWORD_BCRYPT, ['cost' => 12]);

$pdo->prepare('UPDATE admins SET name = ?, email = ?, password = ? WHERE id = 1')
    ->execute([$name, $email, $password]);

echo "[WADDLE] Admin account configured.\n";
PHP
docker compose exec -T -e WADDLE_ADMIN_PASSWORD="${WADDLE_ADMIN_PASSWORD}" php php "{{project_path 'website/src'}}/.waddle_admin_setup.php"
rm -f "./website/src/.waddle_admin_setup.php"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
