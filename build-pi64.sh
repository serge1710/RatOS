#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
cat config/default config/raspberry/default config/raspberry/rpi64 > src/config
# Set src/custompios_path with CustomPiOS/src/update-custompios-paths first.
sudo ./src/build -d -b raspberrypiarm64 "$@"
