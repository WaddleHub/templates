# -------------------------------------------------
# Node.js cron sidecar (extends the Node runtime image).
# -------------------------------------------------
FROM {{integrity_hash 'node/Dockerfile' project_dirname}}

# Install required packages and supercronic for non-root cron execution.
RUN set -eux; \
  {{get_additional_repos public.node.docker}}{{update_repo public.node.docker}}; \
  {{install public.node.docker packages.node_cron.runtime}}; \
  ARCH=$(uname -m | sed 's/x86_64/amd64/g; s/aarch64/arm64/g; s/armv7l/arm/g'); \
  curl -fsSL "https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-${ARCH}" \
    -o /usr/local/bin/supercronic; \
  chmod +x /usr/local/bin/supercronic
