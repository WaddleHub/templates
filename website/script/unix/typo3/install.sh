#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download TYPO3 via Composer.
echo "[WADDLE] Downloading source."
docker compose exec -T php composer create-project \
    "typo3/cms-base-distribution:^{{tags.website.version.major}}.0" \
    "{{project_path 'website/src'}}" --no-interaction

# Ensure public directory exists and mark as fresh install.
mkdir -p "./website/src/public"
touch "./website/src/public/FIRST_INSTALL"

# Run CLI installer, if database is empty.
if [ -z "$(find "./mariadb/data/{{public.website.db_name}}" -maxdepth 1 -name '*.ibd' 2>/dev/null)" ]; then
    echo "[WADDLE] Running TYPO3 setup."
    docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" setup \
        --driver=mysqli \
        --host=db \
        --port=3306 \
        --dbname="{{public.website.db_name}}" \
        --username="${WADDLE_DB_USER}" \
        --password="${WADDLE_DB_PASSWORD}" \
        --admin-username="{{public.website.admin_username}}" \
        --admin-user-password="${WADDLE_ADMIN_PASSWORD}" \
        --admin-email="{{public.website.admin_email}}" \
        --project-name="{{public.website.title}}" \
        --create-site="{{website_url}}" \
        --server-type=other \
        --no-interaction \
        --force
fi

echo "[WADDLE] Flushing cache."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush
