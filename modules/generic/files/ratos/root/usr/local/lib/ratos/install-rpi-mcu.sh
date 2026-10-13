#!/usr/bin/env bash
# Build the Linux host MCU separately from USB board firmware outputs.
set -euo pipefail
[[ ${EUID} -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
target_user="${1:-pi}"
target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
repo="${target_home}/klipper"
config="${target_home}/ratos-configurator/configuration/boards/rpi/firmware.config"
test -f "${config}"
test -f "${repo}/scripts/klipper-mcu.service"
build_dir="$(runuser -u "${target_user}" -- mktemp -d /tmp/ratos-rpi-mcu.XXXXXX)"
trap 'rm -rf "${build_dir}"' EXIT
runuser -u "${target_user}" -- cp "${config}" "${build_dir}/rpi.config"
build_args=(-C "${repo}" "KCONFIG_CONFIG=${build_dir}/rpi.config" "OUT=${build_dir}/out/" "PYTHON=${target_home}/klippy-env/bin/python")
runuser -u "${target_user}" -- make "${build_args[@]}" olddefconfig
runuser -u "${target_user}" -- make "${build_args[@]}" -j2
install -m 0755 "${build_dir}/out/klipper.elf" /usr/local/bin/klipper_mcu
install -m 0644 "${repo}/scripts/klipper-mcu.service" /etc/systemd/system/klipper_mcu.service
systemctl enable klipper_mcu.service
echo "Linux host MCU installed. Start klipper_mcu.service on the running Pi."
