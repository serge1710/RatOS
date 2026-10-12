#!/usr/bin/env bash
# Run the installed Next.js server directly; package-manager updates must not
# change the service entry point. systemd supplies the app WorkingDirectory.
set -euo pipefail
NEXT_SCRIPT="${PWD}/node_modules/next/dist/bin/next"
if [[ ! -r "${NEXT_SCRIPT}" ]]; then
    echo "RatOS startup: Next.js entry point is missing: ${NEXT_SCRIPT}" >&2
    exit 1
fi
exec /usr/bin/node "${NEXT_SCRIPT}" start
