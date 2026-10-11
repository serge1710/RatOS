# RatOS 2.1 / MainsailOS 3 migration

Experimental branch: `v2.1.x-mainsailos3`.

The active build is `.github/workflows/BuildImages.yml`, `config.yml`, and
`modules/`. It uses CustoPiZer, not CustomPiOS. `src/` and the old `config/`
are retained as reference and are not executed by this workflow.

Upstream MainsailOS 3.0.0 commit: `77ff5c1eb2731f53440ff2f251b379e1916964ba`.
CustoPiZer action: `25c5b297fd764f497df9f764efe23e1c0b88710d`.
CustoPiZer container follows upstream `main` (a Git commit is not a container tag).
Crowsnest: `v5.0.12`. RatOS configurator: `v2.1.3` (its embedded configuration
and pinned Klipper fork are required). Imported MainsailOS modules retain
upstream copyright; see LICENSE.MainsailOS.

One Raspberry Pi OS Lite Trixie ARM64 image targets Pi 4, Pi 5, and CM5.
SD boot and USB MCU connection are the supported setup. No CAN module,
CAN tools, CAN network interface, or CAN overlay is installed. The Linux
kernel and upstream board catalog may still contain CAN capabilities.
Select Manta M8P v2.0 and USB in the configurator; printer-specific pins and
USB serial IDs must be chosen on the physical printer.

Common Klipper, Moonraker, Mainsail, Crowsnest, timelapse, Sonar, networking,
and cloud-init modules come from MainsailOS. Module 70 installs RatOS and
migrates Klipper to its required fork. Node 24/pnpm 9 match the existing
RatOS chroot integration. First-boot renaming includes ratos-configurator.
The legacy hotspot and CAN installers are not used.

The Raspberry Pi image URL tracks upstream latest; the downloaded image
is SHA256 checked. The full image build and physical boot must be verified
before this branch is considered ready. Old release automation is omitted;
the build uploads experimental images as Actions artifacts only.

GitHub discussion #2473 could not be retrieved, so its content has not
been applied. Crowsnest v5 was verified directly from the release tag.

## Configurator networking

RatOS v2.1.3 writes legacy wpa_supplicant.conf and uses wpa_cli status.
This image adapts the existing five-argument Wi-Fi installer to a protected
NetworkManager WPA2 profile and adapts the wizard connection-status command.
Raw iw scanning remains available. The systemd ExecStartPre hook reapplies
the adapter after configurator updates and fails on an unknown status bundle.
Country, hidden SSIDs, DHCP and a requested single Wi-Fi band are supported;
a mixed frequency list leaves band selection automatic. The original precise
scan-frequency restriction is not transferred. No legacy dhcpcd or autohotspot
stack is enabled. Test Wi-Fi joining and first-boot renaming on hardware.
