#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

MW_SRC_CONTAINER="{{project_path 'website/src'}}/w"

# Create web root and wiki source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download MediaWiki source via git, from inside the php container rather than on the host: a
# host-side git clone leaves the tree owned by whatever account ran Waddle, and a rootless-Docker
# container's root can create new files alongside them but can never chown them afterward.
echo "[WADDLE] Downloading source."
docker compose exec -T php git clone --depth=1 --branch={{tags.website.version.full_raw}} \
    https://github.com/wikimedia/mediawiki.git "${MW_SRC_CONTAINER}"

# Skins are git submodules, not part of the core checkout, so a plain clone leaves skins/ empty
# and the wiki has no default skin (vector-2022) to render with.
echo "[WADDLE] Downloading default skin."
docker compose exec -T php git -C "${MW_SRC_CONTAINER}" submodule update --init --depth=1 -- skins/Vector

# Install PHP dependencies.
echo "[WADDLE] Installing dependencies."
docker compose exec -T php composer install --no-dev --working-dir="${MW_SRC_CONTAINER}"

# Drop the git metadata, so the project's repository tracks website/src as plain files.
echo "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +

# Run CLI installer.
echo "[WADDLE] Executing installer."
docker compose exec -T php php "${MW_SRC_CONTAINER}/maintenance/install.php" \
    --dbname="{{public.website.db_name}}" \
    --dbuser="${WADDLE_DB_USER}" \
    --dbpass="${WADDLE_DB_PASSWORD}" \
    --dbserver=db \
    --server="{{website_url}}" \
    --scriptpath=/w \
    --lang="{{public.website.language}}" \
    --pass="${WADDLE_ADMIN_PASSWORD}" \
    "{{public.website.title}}" \
    "{{public.website.admin_username}}"

# install.php has no option for the administrator's email address, so the account is created
# without one, and MediaWiki silently skips password resets and other mail to it. Set it, marked
# as confirmed, with the bundled maintenance script.
echo "[WADDLE] Setting administrator email."
docker compose exec -T php php "${MW_SRC_CONTAINER}/maintenance/resetUserEmail.php" \
    --no-reset-password "{{public.website.admin_username}}" "{{public.website.admin_email}}"

# install.php also leaves the wiki's sender addresses empty (MediaWiki then falls back to
# apache@<server name>). Use the project's configured from address, like the other platforms.
# Written to a temporary file in the bind mount, then appended from inside the container, which
# owns LocalSettings.php.
echo "[WADDLE] Configuring mail sender."
cat > "./website/src/.waddle_mail_settings.php" <<'EOF'

# Mail sender, configured by Waddle.
$wgPasswordSender = '{{coalesce public.mail.from_email public.website.admin_email}}';
$wgEmergencyContact = '{{coalesce public.mail.from_email public.website.admin_email}}';
EOF
docker compose exec -T php sh -c "cat '{{project_path 'website/src'}}/.waddle_mail_settings.php' >> '${MW_SRC_CONTAINER}/LocalSettings.php'"
rm -f "./website/src/.waddle_mail_settings.php"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
