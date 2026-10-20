#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

docker compose exec -T php composer update \
    --working-dir="{{project_path 'website/src'}}" --no-interaction
