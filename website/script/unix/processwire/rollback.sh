#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

# Clear ProcessWire's cache after restoring.
if [ -d "./website/src/site/assets/cache" ]; then
    echo "[WADDLE] Clearing cache."
    rm -rf "./website/src/site/assets/cache/"*
fi
