#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Pull the latest changes for the target version. ProcessWire automatically
# applies any pending database upgrades on the next boot after the core files
# are updated.
# echo "[WADDLE] Updating ProcessWire core."
# git -C "./website/src" fetch --tags
# git -C "./website/src" checkout {{tags.website.version.full_raw}}

# Clear ProcessWire's cache to pick up the new version.
echo "[WADDLE] Clearing cache."
rm -rf "./website/src/site/assets/cache/"*
