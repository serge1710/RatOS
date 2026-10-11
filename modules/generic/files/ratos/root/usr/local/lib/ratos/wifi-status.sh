#!/usr/bin/env bash
set -euo pipefail
[[ ${EUID} -eq 0 && $# -eq 1 ]] || exit 1
interface="$1"
[[ "${interface}" =~ ^[a-zA-Z0-9_.:-]+$ ]] || exit 1
[[ "$(nmcli -g GENERAL.STATE device show "${interface}")" == 100* ]] || exit 1
# Treat an access point as disconnected, matching the RatOS wizard's intent.
connection="$(nmcli -g GENERAL.CON-UUID device show "${interface}")"
[[ "$(nmcli -g 802-11-wireless.mode connection show uuid "${connection}")" != ap ]] || exit 1
address="$(nmcli -g IP4.ADDRESS device show "${interface}" | head -n1)"
[[ -n "${address}" ]] || exit 1
printf 'ip_address=%s\n' "${address%%/*}"
