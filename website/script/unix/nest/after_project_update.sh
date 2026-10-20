#!/bin/sh -eu
# Build the website after a deploy/push to a remote environment, and restart it.
# Usage: after_project_update.sh <Local|Production|Stage|Dev>

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"

case "$ENV" in
    Local|Production|Stage|Dev)
        ;;
    *)
        echo "Usage: $0 <Local|Production|Stage|Dev>" >&2
        exit 1
        ;;
esac

# Locally the dev server already serves the current code, so there is nothing to do.
if [ "$ENV" = "Local" ]; then
    exit 0
fi

# Install the dependencies and build the website from the code just pushed. A failed build fails
# the push, and the website already running keeps running.
docker compose run --rm --no-deps -T --entrypoint sh node "{{project_path 'node/script/build.sh'}}"

docker compose restart node
