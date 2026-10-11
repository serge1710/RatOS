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

# Keep the service correction in a drop-in so configurator updates retain it.
PNPM_SCRIPT="$(npm root -g)/pnpm/bin/pnpm.cjs"
test "$(/usr/bin/node "${PNPM_SCRIPT}" --version)" = "9.14.2"
install -d /etc/systemd/system/ratos-configurator.service.d
cat > /etc/systemd/system/ratos-configurator.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/bin/bash /usr/local/lib/ratos/start-configurator.sh
EOF

# v2.1.3's version checker and extensions require its pinned RatOS Klipper fork.
# Upstream's script reads the pin from this configurator's moonraker.conf.
export KLIPPER_DIR="${TARGET_HOME}/klipper" KLIPPER_ENV="${TARGET_HOME}/klippy-env"
# Run Git directly as the target user: upstream captures stderr with the URL,
# so chroot sudo hostname warnings would corrupt repository detection.
chown -R "${TARGET_USER}:${TARGET_USER}" "${KLIPPER_DIR}"
# Ownership changes invalidate Git stat data. Refresh it without discarding edits;
# the upstream migration uses diff-index, which does not refresh the index.
runuser -u "${TARGET_USER}" -- git -C "${KLIPPER_DIR}" update-index --refresh
runuser -u "${TARGET_USER}" -- bash \
    "${REPO_DIR}/configuration/scripts/klipper-fork-migration.sh" --skip-ownership
# Refresh dependencies and chelper after switching from upstream Klipper.
KLIPPER_REQUIREMENTS="${KLIPPER_DIR}/scripts/klippy-requirements.txt"
if "${KLIPPER_ENV}/bin/python" -c 'import sys; sys.exit(sys.version_info < (3, 13))'; then
    # The RatOS fork predates Python 3.13. Keep its source checkout clean and
    # use a temporary requirements copy with compatible native dependencies.
    TMP_CONFIG="$(mktemp /tmp/ratos-klippy-requirements.XXXXXX.txt)"
    sed -E '/^(cffi|greenlet)==/d' "${KLIPPER_REQUIREMENTS}" > "${TMP_CONFIG}"
    printf '\ncffi==2.1.1\ngreenlet==3.3.2\n' >> "${TMP_CONFIG}"
    chmod 644 "${TMP_CONFIG}"
    KLIPPER_REQUIREMENTS="${TMP_CONFIG}"
fi
runuser -u "${TARGET_USER}" -- "${KLIPPER_ENV}/bin/python" -m pip install \
    -r "${KLIPPER_REQUIREMENTS}" pygam
runuser -u "${TARGET_USER}" -- "${KLIPPER_ENV}/bin/python" -c \
    'import pygam, cffi, greenlet; cffi.FFI(); assert greenlet.greenlet(lambda: 42).switch() == 42'
runuser -u "${TARGET_USER}" -- "${KLIPPER_ENV}/bin/python" \
    "${KLIPPER_DIR}/klippy/chelper/__init__.py"
