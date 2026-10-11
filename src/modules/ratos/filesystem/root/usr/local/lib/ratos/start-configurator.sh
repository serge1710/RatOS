#!/usr/bin/env bash
# Invoke pnpm through Node; do not depend on its launcher shebang.
set -euo pipefail
PNPM_SCRIPT="$(/usr/bin/npm root -g)/pnpm/bin/pnpm.cjs"
test -r "${PNPM_SCRIPT}"
exec /usr/bin/node "${PNPM_SCRIPT}" start
