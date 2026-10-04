#!/usr/bin/env bash
# Install the v2.1.3 monorepo into an image without setuid elevation under QEMU.
set -euo pipefail
REPO_DIR="${1:?Configurator repository is required}"
TARGET_USER="${2:?Target user is required}"
[[ "${EUID}" -eq 0 ]]
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
APP_DIR="${REPO_DIR}/app"
test -f "${APP_DIR}/scripts/setup.sh"
test -f "${APP_DIR}/scripts/common.sh"
bash -n "${APP_DIR}/scripts/setup.sh"
bash -n "${APP_DIR}/scripts/common.sh"

# Keep temporary copies beside upstream scripts so BASH_SOURCE path logic works.
TMP_COMMON="$(mktemp "${APP_DIR}/scripts/.ratos-common.XXXXXX.sh")"
TMP_SETUP="$(mktemp "${APP_DIR}/scripts/.ratos-setup.XXXXXX.sh")"
TMP_CONFIG=""
cleanup() { rm -f "${TMP_COMMON}" "${TMP_SETUP}" "${TMP_CONFIG}"; }
trap cleanup EXIT
sed 's/sudo systemctl daemon-reload/: # daemon reload occurs at first boot/' \
    "${APP_DIR}/scripts/common.sh" > "${TMP_COMMON}"
sed -e '/^verify_ready$/d' \
    -e '/^disable_telemetry$/c\export NEXT_TELEMETRY_DISABLED=1' \
    -e "s|/common.sh|/${TMP_COMMON##*/}|" \
    "${APP_DIR}/scripts/setup.sh" > "${TMP_SETUP}"

export HOME="${TARGET_HOME}" USER="${TARGET_USER}" LOGNAME="${TARGET_USER}"
export SUDO_USER="${TARGET_USER}" NEXT_TELEMETRY_DISABLED=1
export RATOS_USERNAME="${TARGET_USER}" RATOS_USERGROUP="${TARGET_USER}"
export RATOS_PRINTER_DATA_DIR="${TARGET_HOME}/printer_data"
# pnpm 9 matches the deployed app's lockfile format and install behaviour.
npm install -g pnpm@9.14.2
bash "${TMP_SETUP}"
chown -R "${TARGET_USER}:${TARGET_USER}" "${REPO_DIR}" "${TARGET_HOME}/printer_data"
