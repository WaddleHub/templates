#!/bin/sh -eux

# Create log dir.
mkdir -p "{{project_path 'node/log'}}"
{{#if public.node.install_cron}}

# Create cron log for accurate permissions.
touch "{{project_path 'node/log/cron.log'}}"
{{/if}}
{{#if (is_equal (get_platform_runtime public.website.platform) 'node')}}

# Since this is the website primary runtime, the container must stay up (idling until the platform
# installer has put the website in place, on a first build).
if [ ! -f "{{project_path 'website/src/package.json'}}" ]; then
    echo "[WADDLE] No website installed yet, waiting for the platform installer."
    exec tail -f /dev/null
fi

cd "{{project_path 'website/src'}}"

# On remotes the website is served from its build, which each deploy makes (node/script/build.sh)
# before restarting this service. Until there is one, on a first deploy, wait for it.
if [ "${NODE_ENV:-}" = "production" ] && [ ! -f node_modules/.waddle-built ]; then
    echo "[WADDLE] The website isn't built yet, waiting for a deploy to build it."
    exec tail -f /dev/null
fi

# If node_modules is missing, install the website's npm dependencies.
if [ ! -d node_modules ]; then
    echo "[WADDLE] Installing the website's npm dependencies."
    npm ci --no-audit --no-fund
fi
{{/if}}

exec "${@}"
