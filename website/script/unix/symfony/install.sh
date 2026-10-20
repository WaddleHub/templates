#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

docker compose exec -T php composer config -g audit.block-insecure false

# --no-git: by default `symfony new` makes website/src a git repository of its own, which the
# project's repository would then only record as a gitlink, leaving clones with an empty
# website/src.
docker compose exec -T php symfony new --webapp --no-git --dir="{{project_path 'website/src'}}" \
    --version={{tags.website.version.major}}.{{tags.website.version.minor}}.*
