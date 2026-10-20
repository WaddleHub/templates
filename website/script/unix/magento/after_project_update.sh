#!/bin/sh -eu
# Run Magento's deployment steps on a remote after a push (see deploy.sh).
# Usage: after_project_update.sh <Local|Production|Stage|Dev>
#
# Local does nothing: Waddle runs this hook locally on a URL change, where after_db_updated.sh
# already runs the local steps.

# Waddle runs hooks as `sh <script>`, which ignores the shebang's flags, so set them here.
set -eu

ENV="${1:-}"

case "$ENV" in
    Local)
        exit 0
        ;;
    Production|Stage|Dev)
        ;;
    *)
        echo "Usage: $0 <Local|Production|Stage|Dev>" >&2
        exit 1
        ;;
esac

. ./website/script/unix/magento/deploy.sh

magento_deploy "$ENV"
