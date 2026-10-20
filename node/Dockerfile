# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.node.docker.from}} AS builder

RUN set -eux; \
  {{get_additional_repos public.node.docker}}{{update_repo public.node.docker}}; \
  {{install public.node.docker packages.node.compiletime}}; \
  rawArch="$(uname -m)"; \
  case "$rawArch" in \
    x86_64) nodeArch="x64" ;; \
    aarch64) nodeArch="arm64" ;; \
    armv7l) nodeArch="armv7l" ;; \
    ppc64le) nodeArch="ppc64le" ;; \
    s390x) nodeArch="s390x" ;; \
    *) echo "[WADDLE ERROR] Unsupported CPU architecture: $rawArch"; exit 1 ;; \
  esac; \
  if grep -qi alpine /etc/os-release; then \
    BASE_URL="https://unofficial-builds.nodejs.org/download/release/{{tags.node.version.full_raw}}"; \
    ARCHIVE="node-{{tags.node.version.full_raw}}-linux-${nodeArch}-musl.tar.xz"; \
  else \
    BASE_URL="https://nodejs.org/dist/{{tags.node.version.full_raw}}"; \
    ARCHIVE="node-{{tags.node.version.full_raw}}-linux-${nodeArch}.tar.xz"; \
  fi; \
  cd /tmp; \
  if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 $BASE_URL/SHASUMS256.txt)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find Node checksum download!"; \
    exit 1; \
  fi; \
  curl -L --retry 3 --retry-delay 5 -O $BASE_URL/SHASUMS256.txt; \
  if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 $BASE_URL/$ARCHIVE)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find Node download: $ARCHIVE"; \
    exit 1; \
  fi; \
  curl -L --retry 3 --retry-delay 5 -O $BASE_URL/$ARCHIVE; \
  grep "$ARCHIVE" SHASUMS256.txt | sha256sum -c -; \
  mkdir -p "{{public.node.prefix}}"; \
  tar -C "{{public.node.prefix}}" -xJf $ARCHIVE --no-same-owner --strip-components=1

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.node.docker.from}}

ENV PATH="{{public.node.prefix}}/bin:$PATH"

# Copy the Node.js runtime from the builder stage.
COPY --from=builder "{{public.node.prefix}}" "{{public.node.prefix}}"

RUN set -eux; \
  {{get_additional_repos public.node.docker}}{{update_repo public.node.docker}}; \
  {{install public.node.docker packages.node.runtime}}; \
  ln -s "{{project_path 'website/src'}}" "{{paths.web_src_shortcut}}"; \
  node --version
