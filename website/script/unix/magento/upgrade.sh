#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Disable Composer's block-insecure audit to allow updating Magento's dev
# dependencies (e.g. phpunit) that carry security advisories unrelated to runtime.
docker compose exec -T php composer config -g audit.block-insecure false

echo "[WADDLE] Updating packages."
docker compose exec -T php composer require-commerce \
    magento/product-community-edition {{tags.website.version.full_raw}} \
    --no-update -d "{{project_path 'website/src'}}"
docker compose exec -T php composer update --dev -d "{{project_path 'website/src'}}"

echo "[WADDLE] Removing cache and log data."
rm -rf "./website/src/var/cache/"*
rm -rf "./website/src/var/page_cache/"*
rm -rf "./website/src/generated/code/"*

# Update sample data if present.
if [ -d "./website/src/sample-data" ]; then
    git -C "./website/src/sample-data" pull --ff-only
fi
