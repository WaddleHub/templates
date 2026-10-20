#!/bin/sh -eu
# Installs the website's npm dependencies from its lock file and, on remotes, builds the website.
# Deploys and rollbacks run it in a one-off node container before restarting the node service:
#
#   docker compose run --rm --no-deps -T --entrypoint sh node "{{project_path 'node/script/build.sh'}}"

cd "{{project_path 'website/src'}}"

echo "[WADDLE] Installing the website's npm dependencies."
# On remotes (NODE_ENV=production) npm ci leaves out the dev dependencies. A platform whose build tools
# are dev dependencies (Like NestJS) fails its build there. So if a platform's build fails on a remote,
# check this first. NestJS installs them as part of its build, and removes them again once built.
npm ci --no-audit --no-fund

if [ "${NODE_ENV:-}" = "production" ]; then
    echo "[WADDLE] Building the website."
    {{get_platform_node_command public.website.platform 'build'}}

    # Tells the node service the website is built and ready to serve. npm ci removes it along
    # with the old node_modules, so after a failed build the node service waits for the next
    # deploy instead of starting a half-built website.
    touch node_modules/.waddle-built
fi
