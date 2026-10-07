![RatOS](site/static/img/logos/Logo-black.svg)

<p align="center">
<a href="https://github.com/Rat-OS/RatOS/releases"><img src="https://img.shields.io/github/downloads/Rat-OS/RatOS/total?color=%2368da0b" /></a>
<a href="http://discord.gg/ratrig"><img src="https://img.shields.io/discord/582187371529764864?color=%235865F2&label=discord&logo=discord&logoColor=white&style=flat" /></a>
</p>

# What is RatOS

RatOS is a preconfigured Raspberry Pi image that aims to make it as painless as possible to get Klipper, Mainsail and Moonraker up and running on your printer. It is developed and maintained by Mikkel Schmidt (miklschmidt#2036 on the Rat Rig Unofficial Discord) with help from the community.

# How to use RatOS

Start by reading the [Documentation](https://os.ratrig.com)

# Build your own / Developing

## Requirements

-   [qemu-arm-static](http://packages.debian.org/sid/qemu-user-static)
-   [CustomPiOS](https://github.com/guysoft/CustomPiOS)
-   [Downloaded Raspbian Image](http://www.raspbian.org/)
-   Bash
-   Git
-   [Docker](https://docs.docker.com/engine/install/ubuntu/)
-   [Docker-Compose](https://docs.docker.com/compose/install/)
-   QEMU for emulation
-   About 5GB of free diskspace for the build
-   Yarn & Docusaurus for docs

## Building

To prevent you have to deal with an entire build chain setup, \
simply fork this repository.

Enable the workflows in your fork and you are good to go. \
On each push you make, an image is build and uploaded as an artifact.

If you want or need to build locally please visit [CustomPiOS](https://github.com/guysoft/CustomPiOS). \
Especially ["Build a Distro From within Raspbian / Debian / Ubuntu / CustomPiOS Distros"](https://github.com/guysoft/CustomPiOS#build-a-distro-from-within-raspbian--debian--ubuntu--custompios-distros)

### Raspberry Pi 4 / Pi 5 / CM5 build

The build and release matrices use `raspberry/rpi64`: Raspberry Pi OS Lite
Trixie ARM64 (AArch64), with CustomPiOS 2.0.0. ARM64 is the architecture
for these boards; x64 refers to Intel/AMD systems.

CustomPiOS 2.0 requires Python YAML support (`python3-yaml`) and an explicit
`BASE_BOARD=raspberrypiarm64` so its generated board config retains ARM64
emulation. RatOS keeps downloaded images in `src/image` using
`BASE_IMAGE_PATH`; the Raspberry Pi boot partition mounts at `/boot/firmware`.
The upstream 2.0 polkit fix replaces the former checkout patch.

The intended printer connection is a BTT Manta M8P V2.0 over USB.
After flashing, select that board in the RatOS configurator and use its
`/dev/serial/by-id/` device for Klipper. No CAN interface setup is added by
this migration. Printer wiring and MCU firmware still need to match USB mode.

## HUGE THANK YOU to the Sponsors

![Rat Rig](sponsors/ratrig-logo.png)

![Intermode](sponsors/intermode-logo.png)
