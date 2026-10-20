#!/bin/sh -eu

# Dump every database into a file, owned by the owner of the directory it's written to.
#
# The dump is written here, inside the container, onto a bind mount, rather than streamed out
# through `docker compose exec`: on Windows, PowerShell decodes a native command's output with the
# console code page, which garbles every non-ASCII character in the dump.
#
# Usage: sh backup.sh <file>
#   <file>  Path inside the container, on a bind-mounted directory (e.g. the mariadb directory).

FILE="${1}"

mysqldump --all-databases > "${FILE}"
chown "$(stat -c %u:%g "$(dirname "${FILE}")")" "${FILE}"
