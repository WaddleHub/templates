#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download and extract PrestaShop source from inside the php container rather than on the host: a
# host-side extraction leaves the tree owned by whatever account ran Waddle, and a rootless-Docker
# container's root can create new files alongside them but can never chown them afterward.
echo "[WADDLE] Downloading source."
docker compose exec -T php curl -L --retry 3 --retry-delay 5 {{tags.website.tar}} -o /tmp/prestashop.tar.gz

echo "[WADDLE] Extracting source."
docker compose exec -T php tar -C "{{project_path 'website/src'}}" -xzf /tmp/prestashop.tar.gz --strip-components=1
docker compose exec -T php rm -f /tmp/prestashop.tar.gz

# Run Composer installation process.
echo "[WADDLE] Executing installer."
docker compose exec -T php composer --working-dir="{{project_path 'website/src'}}" install

# Run NPM assets build process.
docker compose exec -T php sh -c \
    "cd '{{project_path 'website/src'}}' && make assets"

# CLI installer may be in install-dev or install directory.
if [ -f "./website/src/install-dev/index_cli.php" ]; then
    installer_name="install-dev"
elif [ -f "./website/src/install/index_cli.php" ]; then
    installer_name="install"
else
    installer_name=""
fi

if [ -z "${installer_name}" ]; then
    echo "[Website installer] Failed to find CLI installer."
    exit 1
fi

# Clear Symfony DI container cache shipped with the PS source before running the installer.
# The pre-built cache has hardcoded DB settings that cause connection failures via socket.
rm -rf "./website/src/var/cache/"

docker compose exec -T php php "{{project_path 'website/src'}}/${installer_name}/index_cli.php" \
    --title="{{public.website.title}}" \
    --email="{{public.website.admin_email}}" \
    --password="${WADDLE_ADMIN_PASSWORD}" \
    --firstname="{{public.website.admin_firstname}}" \
    --lastname="{{public.website.admin_lastname}}" \
    --domain={{public.website.url}} \
    --db_server=db \
    --db_name={{public.website.db_name}} \
    --db_user="${WADDLE_DB_USER}" \
    --db_password="${WADDLE_DB_PASSWORD}" \
    --db_clear=1 \
    --language="{{public.website.language}}" \
    --timezone={{timezone}} \
    --newsletter=0{{#if ssl.enabled}} --ssl=1{{/if}} 2>&1 | tee /tmp/ps_install.log

# Check for successful installation.
if ! grep -q "Installation successful" /tmp/ps_install.log; then
    echo "[Website installer] PrestaShop installation failed. See output above."
    exit 1
fi

# Remove the installer now that it's done.
docker compose exec -T php rm -rf "{{project_path 'website/src'}}/${installer_name}"

# Remove docker-compose.yml if it exists, to avoid conflicts with the one produced by Waddle.
if [ -f "./website/src/docker-compose.yml" ]; then
    rm -f "./website/src/docker-compose.yml"
fi

# Set admin panel URI if specified. The shipped admin directory is named to match the CLI
# installer directory found above: "admin-dev" alongside "install-dev", or "admin" alongside
# "install".
{{#if (not_empty public.website.admin_route)}}
admin_dir=""
if [ -d "./website/src/admin-dev" ]; then
    admin_dir="admin-dev"
elif [ -d "./website/src/admin" ]; then
    admin_dir="admin"
fi

if [ -n "${admin_dir}" ] && [ "${admin_dir}" != "{{public.website.admin_route}}" ]; then
    echo "[Website installer] Setting admin panel URI to {{public.website.admin_route}}"
    mv "./website/src/${admin_dir}" "./website/src/{{public.website.admin_route}}"
fi
{{/if}}

# The default theme's asset cache doesn't ship in the download at all — CccReducer creates it
# lazily on the theme's first page render — unlike the rest of the daemon-owned list below, which
# ships as empty placeholder directories the chown can act on directly.
docker compose exec -T php mkdir -p "{{project_path 'website/src'}}/themes/hummingbird/assets/cache"

# Configure mail (SMTP to the `mail` service, contact form notifications); see the script.
echo "[WADDLE] Configuring mail."
docker compose exec -T php php "{{project_path 'website/conf/prestashop/configure-mail.php'}}"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
